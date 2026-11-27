import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/officer_location.dart';

enum AdminLiveMapChangeType {
  locationUpdated,
  locationRemoved,
  dutiesChanged,
}

class AdminLiveMapChange {
  const AdminLiveMapChange({
    required this.type,
    this.officerId,
    this.location,
  });

  final AdminLiveMapChangeType type;
  final String? officerId;
  final OfficerLocation? location;
}

class AdminLiveMapRepository {
  AdminLiveMapRepository(this._client);

  final SupabaseClient _client;
  static const int _pageSize = 500;

  RealtimeChannel? _channel;
  String? _subscribedAdminId;
  String? _channelTopic;

  Future<List<OfficerLocation>> fetchLocations() async {
    final rows = <dynamic>[];
    var offset = 0;
    while (true) {
      final page = await _client
          .from('officer_locations')
          .select('officer_id, latitude, longitude, accuracy, updated_at')
          .order('updated_at', ascending: false)
          .range(offset, offset + _pageSize - 1);
      rows.addAll(page);
      if (page.length < _pageSize) break;
      offset += _pageSize;
    }

    debugPrint(
      '[AdminLiveMapData] Supabase location query returned ${rows.length} raw '
      'records from public.officer_locations.',
    );
    for (final row in rows) {
      debugPrint('[AdminLiveMapData] raw location row=$row');
    }

    final locations = rows
        .map((row) => OfficerLocation.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList(growable: false);
    debugPrint(
      '[AdminLiveMapData] Parsed ${locations.length} location records; '
      'officerIds=${locations.map((location) => location.officerId).toList()}.',
    );
    return locations;
  }

  Future<void> subscribe({
    required String adminId,
    required void Function(AdminLiveMapChange change) onChange,
    required void Function(bool connected, String? error) onConnectionChanged,
  }) async {
    if (_channel != null && _subscribedAdminId == adminId) {
      debugPrint(
        '[AdminLiveMapRealtime] Reuse existing channel topic=$_channelTopic '
        'adminId=$adminId; no duplicate subscription created.',
      );
      return;
    }
    await unsubscribe(reason: 'replaced by a different admin session');

    final topic = 'admin-live-map-$adminId';
    debugPrint(
      '[AdminLiveMapRealtime] Creating channel topic=$topic with handlers '
      'public.officer_locations:* and public.duties:*.',
    );
    final channel = _client.channel(topic);
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'officer_locations',
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final id = payload.oldRecord['officer_id']?.toString();
              if (id != null) {
                onChange(AdminLiveMapChange(
                  type: AdminLiveMapChangeType.locationRemoved,
                  officerId: id,
                ));
              }
              return;
            }

            final record = payload.newRecord;
            if (record.isEmpty) return;
            try {
              final location = OfficerLocation.fromJson(record);
              onChange(AdminLiveMapChange(
                type: AdminLiveMapChangeType.locationUpdated,
                officerId: location.officerId,
                location: location,
              ));
            } catch (_) {
              onConnectionChanged(
                true,
                'A location update could not be parsed. Refresh the map.',
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'duties',
          callback: (_) => onChange(const AdminLiveMapChange(
            type: AdminLiveMapChangeType.dutiesChanged,
          )),
        );

    _channel = channel;
    _subscribedAdminId = adminId;
    _channelTopic = topic;
    try {
      channel.subscribe((status, error) {
        final statusLabel = switch (status) {
          RealtimeSubscribeStatus.subscribed => 'SUBSCRIBED',
          RealtimeSubscribeStatus.channelError => 'CHANNEL_ERROR',
          RealtimeSubscribeStatus.timedOut => 'TIMED_OUT',
          RealtimeSubscribeStatus.closed => 'CLOSED',
        };
        debugPrint(
          '[AdminLiveMapRealtime] channel=$topic status=$statusLabel',
        );

        if (error != null) {
          _logRealtimeFailure(
            topic: topic,
            status: statusLabel,
            error: error,
            stackTrace: StackTrace.current,
            stackLabel: 'subscribe callback stack',
          );
        }

        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            onConnectionChanged(true, null);
            break;
          case RealtimeSubscribeStatus.channelError:
          case RealtimeSubscribeStatus.timedOut:
          case RealtimeSubscribeStatus.closed:
            onConnectionChanged(
              false,
              error == null
                  ? 'Realtime $statusLabel. See device logs for diagnostics.'
                  : 'Realtime $statusLabel: $error',
            );
        }
      });
    } catch (error, stackTrace) {
      _logRealtimeFailure(
        topic: topic,
        status: 'SUBSCRIBE_THROW',
        error: error,
        stackTrace: stackTrace,
        stackLabel: 'caught subscription setup stack',
      );
      _channel = null;
      _subscribedAdminId = null;
      _channelTopic = null;
      rethrow;
    }
  }

  void _logRealtimeFailure({
    required String topic,
    required String status,
    required Object error,
    required StackTrace stackTrace,
    required String stackLabel,
  }) {
    debugPrint(
      '[AdminLiveMapRealtime] channel=$topic status=$status '
      'completeError=$error',
    );
    debugPrintStack(
      label: '[AdminLiveMapRealtime] $stackLabel',
      stackTrace: stackTrace,
    );
  }

  Future<void> unsubscribe({
    String reason = 'requested by caller',
  }) async {
    final channel = _channel;
    final topic = _channelTopic;
    _channel = null;
    _subscribedAdminId = null;
    _channelTopic = null;
    if (channel != null) {
      debugPrint(
        '[AdminLiveMapRealtime] Removing channel topic=$topic reason=$reason.',
      );
      await _client.removeChannel(channel);
    } else {
      debugPrint(
        '[AdminLiveMapRealtime] No channel to remove reason=$reason.',
      );
    }
  }
}
