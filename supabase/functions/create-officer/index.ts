import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
};

type ErrorCode =
  | 'UNAUTHORIZED'
  | 'FORBIDDEN'
  | 'INVALID_INPUT'
  | 'EMAIL_ALREADY_EXISTS'
  | 'WEAK_PASSWORD'
  | 'PROFILE_WRITE_FAILED'
  | 'INTERNAL_ERROR';

function jsonResponse(
  status: number,
  body: Record<string, unknown>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

function authErrorCode(code: string | undefined, message: string): ErrorCode {
  const normalized = `${code ?? ''} ${message}`.toLowerCase();
  if (
    normalized.includes('email_exists') ||
    normalized.includes('user_already_exists') ||
    normalized.includes('already registered') ||
    normalized.includes('already been registered')
  ) {
    return 'EMAIL_ALREADY_EXISTS';
  }
  if (
    normalized.includes('weak_password') ||
    normalized.includes('password') && normalized.includes('least')
  ) {
    return 'WEAK_PASSWORD';
  }
  return 'INTERNAL_ERROR';
}

function authErrorResponse(code: ErrorCode): Response {
  switch (code) {
    case 'EMAIL_ALREADY_EXISTS':
      return jsonResponse(409, {
        code,
        message: 'An account with this email already exists.',
      });
    case 'WEAK_PASSWORD':
      return jsonResponse(422, {
        code,
        message: 'The password does not meet the Supabase password requirements.',
      });
    default:
      return jsonResponse(500, {
        code,
        message: 'The officer account could not be created.',
      });
  }
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return jsonResponse(405, {
      code: 'INVALID_INPUT',
      message: 'Only POST requests are supported.',
    });
  }

  const authorization = request.headers.get('Authorization');
  const bearerMatch = authorization?.match(/^Bearer\s+(.+)$/i);
  if (!bearerMatch) {
    return jsonResponse(401, {
      code: 'UNAUTHORIZED',
      message: 'A valid authenticated session is required.',
    });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    console.error('Required Supabase Edge Function secrets are not configured.');
    return jsonResponse(500, {
      code: 'INTERNAL_ERROR',
      message: 'Officer creation is not configured.',
    });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const { data: userData, error: userError } =
    await adminClient.auth.getUser(bearerMatch[1]);
  if (userError || !userData.user) {
    return jsonResponse(401, {
      code: 'UNAUTHORIZED',
      message: 'The authenticated session is invalid or expired.',
    });
  }

  const { data: profile, error: profileError } = await adminClient
    .from('profiles')
    .select('role')
    .eq('id', userData.user.id)
    .maybeSingle();

  if (profileError) {
    console.error('Could not verify the caller profile:', profileError.message);
    return jsonResponse(500, {
      code: 'INTERNAL_ERROR',
      message: 'The caller role could not be verified.',
    });
  }
  if (profile?.role !== 'ADMIN') {
    return jsonResponse(403, {
      code: 'FORBIDDEN',
      message: 'Only administrators can create officer accounts.',
    });
  }

  let body: Record<string, unknown>;
  try {
    const parsed = await request.json();
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
      throw new Error('Request body must be an object.');
    }
    body = parsed as Record<string, unknown>;
  } catch {
    return jsonResponse(400, {
      code: 'INVALID_INPUT',
      message: 'A valid JSON request body is required.',
    });
  }

  const fullName =
    typeof body.full_name === 'string' ? body.full_name.trim() : '';
  const email =
    typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  const password = typeof body.password === 'string' ? body.password : '';

  if (
    !fullName ||
    fullName.length > 100 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
    email.length > 254 ||
    password.length < 8
  ) {
    return jsonResponse(400, {
      code: 'INVALID_INPUT',
      message: 'Enter a name, valid email, and password of at least 8 characters.',
    });
  }

  // The client cannot supply a role. Every account created here is an OFFICER.
  const { data: created, error: createError } =
    await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName },
    });

  if (createError || !created.user) {
    if (createError) {
      const code = authErrorCode(createError.code, createError.message);
      if (code === 'EMAIL_ALREADY_EXISTS' || code === 'WEAK_PASSWORD') {
        return authErrorResponse(code);
      }
      console.error('Supabase Auth failed to create officer:', {
        code: createError.code,
        message: createError.message,
      });
    }
    return jsonResponse(500, {
      code: 'INTERNAL_ERROR',
      message: 'The officer account could not be created.',
    });
  }

  // The existing auth trigger may have inserted this row already. Upsert on the
  // profile primary key updates that row and cannot create a duplicate profile.
  const { error: profileWriteError } = await adminClient
    .from('profiles')
    .upsert(
      {
        id: created.user.id,
        full_name: fullName,
        role: 'OFFICER',
      },
      { onConflict: 'id' },
    );

  if (profileWriteError) {
    console.error('Could not finalize officer profile:', profileWriteError.message);
    const { error: rollbackError } =
      await adminClient.auth.admin.deleteUser(created.user.id);
    if (rollbackError) {
      console.error('Could not roll back newly created Auth user:', rollbackError.message);
    }
    return jsonResponse(500, {
      code: 'PROFILE_WRITE_FAILED',
      message: 'The officer profile could not be saved. No officer was added.',
    });
  }

  return jsonResponse(201, {
    id: created.user.id,
    email: created.user.email,
    full_name: fullName,
    role: 'OFFICER',
  });
});
