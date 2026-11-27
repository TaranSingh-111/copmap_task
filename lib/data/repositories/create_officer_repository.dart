import 'package:supabase_flutter/supabase_flutter.dart';

enum CreateOfficerFailureType {
  unauthorized,
  forbidden,
  invalidInput,
  duplicateEmail,
  weakPassword,
  network,
  unknown,
}

class CreateOfficerException implements Exception {
  const CreateOfficerException(this.type, this.message);

  final CreateOfficerFailureType type;
  final String message;

  @override
  String toString() => message;
}

class CreatedOfficer {
  const CreatedOfficer({
    required this.id,
    required this.email,
    required this.fullName,
  });

  final String id;
  final String email;
  final String fullName;
}

class CreateOfficerRepository {
  CreateOfficerRepository(this._client);

  final SupabaseClient _client;

  Future<CreatedOfficer> createOfficer({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (_client.auth.currentSession == null) {
      throw const CreateOfficerException(
        CreateOfficerFailureType.unauthorized,
        'Sign in with an administrator account to create officers.',
      );
    }

    try {
      final response = await _client.functions.invoke(
        'create-officer',
        body: {
          'full_name': fullName.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );
      final data = response.data;
      if (response.status < 200 || response.status >= 300) {
        throw _exceptionFromBody(data);
      }
      if (data is! Map) {
        throw const CreateOfficerException(
          CreateOfficerFailureType.unknown,
          'The server returned an invalid response.',
        );
      }
      return CreatedOfficer(
        id: data['id']?.toString() ?? '',
        email: data['email']?.toString() ?? email.trim().toLowerCase(),
        fullName: data['full_name']?.toString() ?? fullName.trim(),
      );
    } on CreateOfficerException {
      rethrow;
    } on FunctionsFetchException {
      throw const CreateOfficerException(
        CreateOfficerFailureType.network,
        'Could not reach the server. Check your connection and try again.',
      );
    } on FunctionException catch (error) {
      throw _exceptionFromStatus(error.status, error.details);
    } on AuthException {
      throw const CreateOfficerException(
        CreateOfficerFailureType.unauthorized,
        'Your session is no longer valid. Sign in again.',
      );
    } catch (_) {
      throw const CreateOfficerException(
        CreateOfficerFailureType.unknown,
        'The officer account could not be created. Please try again.',
      );
    }
  }

  CreateOfficerException _exceptionFromBody(dynamic body) {
    if (body is Map) {
      final code = body['code']?.toString();
      final message = body['message']?.toString();
      return _exceptionFromCode(code, message);
    }
    return _exceptionFromStatus(500, body);
  }

  CreateOfficerException _exceptionFromStatus(int status, dynamic details) {
    final body = details is Map ? details : null;
    final code = body?['code']?.toString();
    final message = body?['message']?.toString();
    if (code != null || message != null) {
      return _exceptionFromCode(code, message);
    }
    return switch (status) {
      401 => const CreateOfficerException(
          CreateOfficerFailureType.unauthorized,
          'Your session is invalid or expired. Sign in again.',
        ),
      403 => const CreateOfficerException(
          CreateOfficerFailureType.forbidden,
          'Only administrators can create officer accounts.',
        ),
      409 => const CreateOfficerException(
          CreateOfficerFailureType.duplicateEmail,
          'An account with this email already exists.',
        ),
      422 => const CreateOfficerException(
          CreateOfficerFailureType.weakPassword,
          'The password does not meet the account security requirements.',
        ),
      400 => const CreateOfficerException(
          CreateOfficerFailureType.invalidInput,
          'Check the name, email, and password and try again.',
        ),
      0 => const CreateOfficerException(
          CreateOfficerFailureType.network,
          'Could not reach the server. Check your connection and try again.',
        ),
      _ => const CreateOfficerException(
          CreateOfficerFailureType.unknown,
          'The officer account could not be created. Please try again.',
        ),
    };
  }

  CreateOfficerException _exceptionFromCode(String? code, String? message) {
    switch (code) {
      case 'UNAUTHORIZED':
        return const CreateOfficerException(
          CreateOfficerFailureType.unauthorized,
          'Your session is invalid or expired. Sign in again.',
        );
      case 'FORBIDDEN':
        return const CreateOfficerException(
          CreateOfficerFailureType.forbidden,
          'Only administrators can create officer accounts.',
        );
      case 'EMAIL_ALREADY_EXISTS':
        return const CreateOfficerException(
          CreateOfficerFailureType.duplicateEmail,
          'An account with this email already exists.',
        );
      case 'WEAK_PASSWORD':
        return const CreateOfficerException(
          CreateOfficerFailureType.weakPassword,
          'The password does not meet the account security requirements.',
        );
      case 'INVALID_INPUT':
        return CreateOfficerException(
          CreateOfficerFailureType.invalidInput,
          message ?? 'Check the name, email, and password and try again.',
        );
      default:
        return CreateOfficerException(
          CreateOfficerFailureType.unknown,
          message ?? 'The officer account could not be created. Please try again.',
        );
    }
  }
}
