import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/duty_model.dart';

class DutyRepository {
  DutyRepository(this._client);

  final SupabaseClient _client;
  static const int _pageSize = 500;

  Future<List<DutyModel>> fetchActiveDuties() async {
    final rows = <dynamic>[];
    var offset = 0;
    while (true) {
      final page = await _client
          .from('duties')
          .select(
            'id, title, assigned_to, status, location_name, start_time, end_time',
          )
          .eq('status', 'IN_PROGRESS')
          .order('start_time', ascending: false, nullsFirst: false)
          .range(offset, offset + _pageSize - 1);
      rows.addAll(page);
      if (page.length < _pageSize) break;
      offset += _pageSize;
    }
    return _mapDuties(rows);
  }

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
    return _mapDuties(rows);
  }

  Future<List<DutyModel>> fetchAllDuties() async {
    final rows = <dynamic>[];
    var offset = 0;
    while (true) {
      final page = await _client
          .from('duties')
          .select()
          .order('start_time', ascending: true, nullsFirst: false)
          .range(offset, offset + _pageSize - 1);
      rows.addAll(page);
      if (page.length < _pageSize) break;
      offset += _pageSize;
    }
    return _mapDuties(rows);
  }

  Future<DutyModel> createDuty(DutyDraft draft) async {
    final validationError = draft.validate();
    if (validationError != null) throw ArgumentError(validationError);

    final adminId = _client.auth.currentUser?.id;
    if (adminId == null) {
      throw StateError('An authenticated admin is required to create duties.');
    }

    final assignedTo = _normalizeAssignee(draft.assignedTo);
    final row = await _client
        .from('duties')
        .insert({
          ..._editableFields(draft),
          'assigned_to': assignedTo,
          'status': assignedTo == null ? 'PENDING' : 'ASSIGNED',
          'created_by': adminId,
        })
        .select()
        .single();
    return DutyModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<DutyModel> updateDuty({
    required DutyModel existingDuty,
    required DutyDraft draft,
  }) async {
    final validationError = draft.validate();
    if (validationError != null) throw ArgumentError(validationError);
    if (existingDuty.status.isTerminal) {
      throw StateError('Completed or cancelled duties cannot be edited.');
    }

    final fields = _editableFields(draft);
    final assignedTo = _normalizeAssignee(draft.assignedTo);
    fields['assigned_to'] = assignedTo;
    if (existingDuty.status == DutyStatus.pending ||
        existingDuty.status == DutyStatus.assigned) {
      fields['status'] = assignedTo == null ? 'PENDING' : 'ASSIGNED';
    }

    final row = await _client
        .from('duties')
        .update(fields)
        .eq('id', existingDuty.id)
        .not('status', 'in', '("COMPLETED","CANCELLED")')
        .select()
        .maybeSingle();
    if (row == null) {
      throw StateError('This duty is no longer editable.');
    }
    return DutyModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> cancelDuty(DutyModel duty) async {
    if (duty.status.isTerminal) {
      throw StateError('Completed or cancelled duties cannot be cancelled.');
    }
    final row = await _client
        .from('duties')
        .update({'status': 'CANCELLED'})
        .eq('id', duty.id)
        .not('status', 'in', '("COMPLETED","CANCELLED")')
        .select('id')
        .maybeSingle();
    if (row == null) {
      throw StateError('This duty is already completed or cancelled.');
    }
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

  List<DutyModel> _mapDuties(List<dynamic> rows) => rows
      .map((row) => DutyModel.fromJson(Map<String, dynamic>.from(row)))
      .toList(growable: false);

  Map<String, dynamic> _editableFields(DutyDraft draft) => {
        'title': draft.title.trim(),
        'description': _normalizeText(draft.description),
        'location_name': _normalizeText(draft.locationName),
        'latitude': draft.latitude,
        'longitude': draft.longitude,
        'start_time': draft.startTime.toUtc().toIso8601String(),
        'end_time': draft.endTime.toUtc().toIso8601String(),
      };

  String? _normalizeAssignee(String? assignedTo) {
    final value = assignedTo?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? _normalizeText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
