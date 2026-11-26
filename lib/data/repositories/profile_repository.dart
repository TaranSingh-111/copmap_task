import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<UserProfile> fetchForUser(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (row == null) {
      throw StateError('No profile exists for the authenticated account.');
    }
    return UserProfile.fromJson(row);
  }
}
