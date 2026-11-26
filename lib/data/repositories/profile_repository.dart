import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;
  static const int _pageSize = 500;

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

  Future<List<UserProfile>> fetchOfficers() async {
    final rows = <dynamic>[];
    var offset = 0;
    while (true) {
      final page = await _client
          .from('profiles')
          .select('id, full_name, role, created_at')
          .eq('role', 'OFFICER')
          .order('full_name')
          .range(offset, offset + _pageSize - 1);
      rows.addAll(page);
      if (page.length < _pageSize) break;
      offset += _pageSize;
    }

    return rows
        .map((row) => UserProfile.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }
}
