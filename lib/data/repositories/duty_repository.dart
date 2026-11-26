import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/duty_model.dart';

class DutyRepository {
  DutyRepository(this._client);
  final SupabaseClient _client;

  Future<List<DutyModel>> fetchAssignedDuties() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('An authenticated officer is required to load duties.');
    }
    final rows = await _client
        .from('duties')
        .select()
        .eq('assigned_to', userId)
        .order('start_time', ascending: true, nullsFirst: false);
    return rows
        .map((row) => DutyModel.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<void> transitionStatus({
    required String dutyId,
    required DutyStatus newStatus,
  }) async {
    if (newStatus != DutyStatus.inProgress &&
        newStatus != DutyStatus.completed) {
      throw ArgumentError.value(
        newStatus, 'newStatus', 'Officers may only start or complete a duty.',
      );
    }
    await _client.rpc(
      'update_duty_status',
      params: {
        'p_duty_id': dutyId,
        'p_new_status': newStatus.databaseValue,
      },
    );
  }
}
