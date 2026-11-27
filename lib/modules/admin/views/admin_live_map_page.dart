import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../data/models/officer_live_map_entry.dart';
import '../controllers/admin_live_map_controller.dart';

class AdminLiveMapPage extends GetView<AdminLiveMapController> {
  const AdminLiveMapPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Live officer map'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: controller.loadMap,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Obx(() {
          if (controller.loadState.value == AdminLiveMapLoadState.loading &&
              controller.officers.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.loadState.value == AdminLiveMapLoadState.error &&
              controller.officers.isEmpty) {
            return _ErrorState(
              message: controller.loadError.value ??
                  'Could not load the officer map.',
              onRetry: controller.loadMap,
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadMap,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              children: [
                if (controller.loadError.value != null)
                  _InlineStatus(
                    message: controller.loadError.value!,
                    isError: true,
                  ),
                if (controller.realtimeError.value != null)
                  _InlineStatus(
                    message: controller.realtimeError.value!,
                    isError: true,
                  )
                else if (!controller.realtimeConnected.value)
                  const _InlineStatus(
                    message: 'Connecting to live location updates…',
                    isError: false,
                  ),
                _LiveMapPanel(controller: controller),
                const SizedBox(height: 20),
                _OfficerLocationList(controller: controller),
                if (controller.selectedEntry != null)
                  _SelectedOfficerCard(entry: controller.selectedEntry!),
                const SizedBox(height: 18),
                _OfficerSection(
                  title: 'Stale locations',
                  subtitle: 'Last known positions older than 2 minutes',
                  icon: Icons.location_searching,
                  entries: controller.staleEntries,
                  emptyMessage: 'No stale locations.',
                  onTap: controller.selectOfficer,
                ),
                const SizedBox(height: 16),
                _OfficerSection(
                  title: 'No location yet',
                  subtitle: 'Officers without a location record',
                  icon: Icons.location_off_outlined,
                  entries: controller.officersWithoutLocation,
                  emptyMessage: controller.officers.isEmpty
                      ? 'No officer profiles are visible. Check admin SELECT '
                          'access for profiles.'
                      : 'Every officer currently has a location record.',
                  onTap: controller.selectOfficer,
                ),
              ],
            ),
          );
        }),
      );
}

class _OfficerLocationList extends StatelessWidget {
  const _OfficerLocationList({required this.controller});

  final AdminLiveMapController controller;

  @override
  Widget build(BuildContext context) {
    final entries = controller.sortedLocationEntries;
    final now = controller.clock.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Officer Locations', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No officer profiles available.'),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100
                  ? 3
                  : constraints.maxWidth >= 680
                      ? 2
                      : 1;
              final spacing = 12.0;
              final cardWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final entry in entries)
                    SizedBox(
                      width: cardWidth,
                      child: _OfficerLocationCard(entry: entry, now: now),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _OfficerLocationCard extends StatelessWidget {
  const _OfficerLocationCard({required this.entry, required this.now});

  final OfficerLiveMapEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final location = entry.location;
    final status = entry.locationStatusAt(now);
    final statusColor = switch (status) {
      OfficerLocationStatus.current => AppColors.success,
      OfficerLocationStatus.stale => AppColors.warning,
      OfficerLocationStatus.noLocation => AppColors.secondaryText,
    };
    final statusLabel = switch (status) {
      OfficerLocationStatus.current => 'CURRENT',
      OfficerLocationStatus.stale => 'STALE',
      OfficerLocationStatus.noLocation => 'NO LOCATION',
    };
    final timestamp = location == null
        ? null
        : _formatTimestamp(location.updatedAt);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Semantics(
                    label: 'Location status: $statusLabel',
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _LocationValueLine(
              label: 'Latitude',
              value: location == null
                  ? 'Coordinates unavailable'
                  : location.latitude.toStringAsFixed(6),
            ),
            _LocationValueLine(
              label: 'Longitude',
              value: location == null
                  ? 'Coordinates unavailable'
                  : location.longitude.toStringAsFixed(6),
            ),
            _LocationValueLine(
              label: 'Accuracy',
              value: location?.accuracy == null
                  ? 'Unavailable'
                  : '${location!.accuracy!.toStringAsFixed(1)} m',
            ),
            const SizedBox(height: 4),
            if (timestamp == null)
              const Text('Last update unavailable')
            else
              Tooltip(
                message: 'Exact timestamp: $timestamp',
                child: Semantics(
                  label: 'Updated ${_relativeLocationTime(location!.updatedAt, now)}. Exact timestamp: $timestamp',
                  child: Text(
                    _relativeLocationTime(location.updatedAt, now),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LocationValueLine extends StatelessWidget {
  const _LocationValueLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 76,
              child: Text(label, style: Theme.of(context).textTheme.labelMedium),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}

String _relativeLocationTime(DateTime updatedAt, DateTime now) {
  final age = now.toUtc().difference(updatedAt.toUtc());
  if (age.isNegative) return 'Timestamp is in the future';
  if (age.inSeconds < 10) return 'Updated just now';
  if (age.inMinutes < 1) return 'Updated ${age.inSeconds} seconds ago';
  if (age.inHours < 1) {
    final minutes = age.inMinutes;
    return 'Updated $minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
  }
  if (age.inDays < 1) {
    final hours = age.inHours;
    return 'Updated $hours ${hours == 1 ? 'hour' : 'hours'} ago';
  }
  final days = age.inDays;
  return 'Updated $days ${days == 1 ? 'day' : 'days'} ago';
}

class _LiveMapPanel extends StatefulWidget {
  const _LiveMapPanel({required this.controller});

  final AdminLiveMapController controller;

  @override
  State<_LiveMapPanel> createState() => _LiveMapPanelState();
}

class _LiveMapPanelState extends State<_LiveMapPanel> {
  GoogleMapController? _mapController;
  bool _didInitialFit = false;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 400,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Obx(() {
            final entries = widget.controller.freshEntries;
            final markers = entries.map((entry) {
              final location = entry.location!;
              return Marker(
                markerId: MarkerId(entry.officer.id),
                position: LatLng(location.latitude, location.longitude),
                infoWindow: InfoWindow(
                  title: entry.displayName,
                  snippet: entry.activeDuty?.title ?? 'No active duty',
                ),
                onTap: () =>
                    widget.controller.selectOfficer(entry.officer.id),
              );
            }).toSet();
            final markerIds = markers.map((marker) => marker.markerId.value).toList();
            debugPrint(
              '[AdminLiveMapMarkers] freshEntries=${entries.length} '
              'markers=${markers.length} uniqueMarkerIds=${markerIds.toSet().length} '
              'markerIds=$markerIds '
              'positions=${markers.map((marker) => '${marker.position.latitude},${marker.position.longitude}').toList()}.',
            );

            if (!_didInitialFit && entries.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _fitMarkers();
              });
            }

            return Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(20.5937, 78.9629),
                    zoom: 4,
                  ),
                  markers: markers,
                  mapToolbarEnabled: false,
                  myLocationButtonEnabled: false,
                  onMapCreated: (mapController) {
                    _mapController = mapController;
                    debugPrint(
                      '[AdminLiveMapCamera] GoogleMap controller initialized; '
                      'freshEntries=${widget.controller.freshEntries.length}.',
                    );
                    _fitMarkers();
                  },
                ),
                if (markers.isEmpty)
                  const Align(
                    alignment: Alignment.center,
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Text('Waiting for fresh officer locations'),
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'fit_officer_markers',
                    tooltip: 'Show all fresh locations',
                    onPressed: _fitMarkers,
                    child: const Icon(Icons.center_focus_strong),
                  ),
                ),
              ],
            );
          }),
        ),
      );

  Future<void> _fitMarkers() async {
    final map = _mapController;
    final entries = widget.controller.freshEntries;
    if (map == null || entries.isEmpty) {
      debugPrint(
        '[AdminLiveMapCamera] Fit skipped mapControllerReady=${map != null} '
        'freshEntries=${entries.length}.',
      );
      return;
    }

    _didInitialFit = true;
    final points = entries
        .map((entry) => entry.location!)
        .toList(growable: false);
    final latitudes = points.map((point) => point.latitude);
    final longitudes = points.map((point) => point.longitude);
    final south = latitudes.reduce((a, b) => a < b ? a : b);
    final north = latitudes.reduce((a, b) => a > b ? a : b);
    final west = longitudes.reduce((a, b) => a < b ? a : b);
    final east = longitudes.reduce((a, b) => a > b ? a : b);

    if (points.length == 1 || (north - south < 0.0001 && east - west < 0.0001)) {
      debugPrint(
        '[AdminLiveMapCamera] Centering on officer coordinate '
        'latitude=${points.first.latitude} longitude=${points.first.longitude} '
        'zoom=14.',
      );
      await map.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(points.first.latitude, points.first.longitude),
          zoom: 14,
        ),
      ));
      return;
    }

    debugPrint(
      '[AdminLiveMapCamera] Fitting ${points.length} officer positions '
      'bounds=south:$south west:$west north:$north east:$east.',
    );
    await map.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(south, west),
        northeast: LatLng(north, east),
      ),
      48,
    ));
  }
}

class _SelectedOfficerCard extends StatelessWidget {
  const _SelectedOfficerCard({required this.entry});

  final OfficerLiveMapEntry entry;

  @override
  Widget build(BuildContext context) {
    final location = entry.location;
    if (location == null) return const SizedBox.shrink();
    final fresh = entry.isFreshAt(DateTime.now().toUtc());
    final accuracy = location.accuracy;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.person_pin_circle_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Text(entry.displayName,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Chip(
              label: Text(fresh ? 'FRESH' : 'STALE'),
              visualDensity: VisualDensity.compact,
            ),
          ]),
          const SizedBox(height: 8),
          _DetailLine(
            label: 'Active duty',
            value: entry.activeDuty?.title ?? 'No active duty',
          ),
          _DetailLine(
            label: 'Coordinates',
            value:
                '${location.latitude.toStringAsFixed(6)}, '
                '${location.longitude.toStringAsFixed(6)}',
          ),
          _DetailLine(
            label: 'Accuracy',
            value: accuracy == null
                ? 'Unavailable'
                : '±${accuracy.toStringAsFixed(0)} m',
          ),
          _DetailLine(
            label: fresh ? 'Last updated' : 'Last seen',
            value: _formatTimestamp(location.updatedAt),
          ),
        ]),
      ),
    );
  }
}

class _OfficerSection extends StatelessWidget {
  const _OfficerSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.entries,
    required this.emptyMessage,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<OfficerLiveMapEntry> entries;
  final String emptyMessage;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            Text(entries.length.toString()),
          ]),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(emptyMessage),
            )
          else
            ...entries.map((entry) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(entry.hasLocation
                          ? Icons.history
                          : Icons.person_outline),
                    ),
                    title: Text(entry.displayName),
                    subtitle: Text(entry.location == null
                        ? 'No location yet'
                        : 'Last update: '
                            '${_formatTimestamp(entry.location!.updatedAt)}\n'
                            '${entry.activeDuty?.title ?? 'No active duty'}'),
                    isThreeLine: entry.location != null,
                    onTap: () => onTap(entry.officer.id),
                  ),
                )),
        ],
      );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 104,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ]),
      );
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          message,
          style: TextStyle(
            color: isError ? Theme.of(context).colorScheme.error : null,
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      );
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
}
