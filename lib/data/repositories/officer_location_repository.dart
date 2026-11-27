import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/officer_location.dart';

class OfficerLocationRepository {
  OfficerLocationRepository(this._client);

  final SupabaseClient _client;

  Future<void> upsertLocation(OfficerLocation location) async {
    const table = 'officer_locations';
    const conflictColumn = 'officer_id';
    final currentUserId = _client.auth.currentUser?.id;
    final payload = location.toJson();

    debugPrint(
      '[OfficerLocationUpload] STAGE 5: Supabase upsert starting '
      'table=public.$table onConflict=$conflictColumn '
      'currentUserId=$currentUserId payloadOfficerId=${location.officerId} '
      'userMatches=${currentUserId != null && currentUserId == location.officerId} '
      'payloadKeys=${payload.keys.toList()}',
    );
    if (currentUserId == null || currentUserId != location.officerId) {
      final error = StateError(
        'The location does not belong to the current authenticated user.',
      );
      debugPrint('[OfficerLocationUpload] STAGE 5 FAILED before request: $error');
      throw error;
    }

    try {
      final response = await _client
          .from(table)
          .upsert(payload, onConflict: conflictColumn);
      debugPrint(
        '[OfficerLocationUpload] STAGE 6: Supabase upsert response received '
        'table=public.$table onConflict=$conflictColumn response=$response',
      );
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        '[OfficerLocationUpload] STAGE 6 FAILED: Supabase exception '
        'table=public.$table onConflict=$conflictColumn '
        'code=${error.code} message=${error.message} '
        'details=${error.details} hint=${error.hint}',
      );
      debugPrintStack(label: '[OfficerLocationUpload] Supabase exception stack', stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      debugPrint(
        '[OfficerLocationUpload] STAGE 6 FAILED: non-PostgREST upsert error '
        'table=public.$table onConflict=$conflictColumn error=$error',
      );
      debugPrintStack(label: '[OfficerLocationUpload] Supabase request stack', stackTrace: stackTrace);
      rethrow;
    }
  }
}
