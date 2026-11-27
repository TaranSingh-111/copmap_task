import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/officer_location.dart';

class OfficerLocationRepository {
  OfficerLocationRepository(this._client);

  final SupabaseClient _client;

  Future<void> upsertLocation(OfficerLocation location) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId != location.officerId) {
      throw StateError('The location does not belong to the current user.');
    }

    await _client.from('officer_locations').upsert(
          location.toJson(),
          onConflict: 'officer_id',
        );
  }
}
