import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/auth_service.dart';
import '../../../data/models/duty_model.dart';
import '../../../data/models/officer_live_map_entry.dart';
import '../../../data/models/officer_location.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/admin_live_map_repository.dart';
import '../../../data/repositories/duty_repository.dart';
import '../../../data/repositories/profile_repository.dart';

enum AdminLiveMapLoadState { loading, success, error }

class AdminLiveMapController extends GetxController
    with WidgetsBindingObserver {
  AdminLiveMapController(
    this._authService,
    this._profileRepository,
    this._dutyRepository,
    this._mapRepository,
  );

  final AuthService _authService;
  final ProfileRepository _profileRepository;
  final DutyRepository _dutyRepository;
  final AdminLiveMapRepository _mapRepository;

  final officers = <UserProfile>[].obs;
  final locations = <String, OfficerLocation>{}.obs;
  final activeDutiesByOfficer = <String, DutyModel>{}.obs;
  final clock = DateTime.now().toUtc().obs;
  final selectedOfficerId = RxnString();
  final loadState = AdminLiveMapLoadState.loading.obs;
  final loadError = RxnString();
  final realtimeError = RxnString();
  final realtimeConnected = false.obs;

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _freshnessTimer;
  String? _sessionUserId;
  int _loadRevision = 0;
  bool _loadInProgress = false;
  bool _realtimeStarted = false;
  bool _bufferChanges = false;
  bool _closed = false;
  bool _dutyRefreshInProgress = false;
  bool _dutyRefreshPending = false;
  final List<AdminLiveMapChange> _bufferedChanges = [];

  List<OfficerLiveMapEntry> get entries {
    return officers
        .map((officer) => OfficerLiveMapEntry(
              officer: officer,
              location: locations[officer.id],
              activeDuty: activeDutiesByOfficer[officer.id],
            ))
        .toList(growable: false);
  }

  List<OfficerLiveMapEntry> get sortedLocationEntries {
    final now = clock.value;
    final sorted = entries.toList(growable: true)
      ..sort((first, second) {
        final statusOrder = first
            .locationStatusAt(now)
            .sortOrder
            .compareTo(second.locationStatusAt(now).sortOrder);
        if (statusOrder != 0) return statusOrder;
        return first.displayName.toLowerCase().compareTo(
              second.displayName.toLowerCase(),
            );
      });
    return sorted;
  }

  List<OfficerLiveMapEntry> get freshEntries =>
      entries.where((entry) => entry.isFreshAt(clock.value)).toList();

  List<OfficerLiveMapEntry> get staleEntries => entries
      .where((entry) => entry.hasLocation && !entry.isFreshAt(clock.value))
      .toList();

  List<OfficerLiveMapEntry> get officersWithoutLocation =>
      entries.where((entry) => !entry.hasLocation).toList();

  OfficerLiveMapEntry? get selectedEntry {
    final id = selectedOfficerId.value;
    if (id == null) return null;
    for (final entry in entries) {
      if (entry.officer.id == id) return entry;
    }
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _sessionUserId = _authService.currentUser?.id;
    _authSubscription = _authService.authStateChanges.listen(
      (event) => _handleSessionChange(event.session?.user.id),
    );
    unawaited(loadMap());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _sessionUserId != null &&
        loadState.value == AdminLiveMapLoadState.success) {
      unawaited(loadMap(showLoading: false));
    }
  }

  Future<void> loadMap({bool showLoading = true}) async {
    if (_loadInProgress || _closed) return;
    final adminId = _sessionUserId;
    final revision = ++_loadRevision;
    _loadInProgress = true;
    _bufferChanges = true;
    if (showLoading) loadState.value = AdminLiveMapLoadState.loading;
    loadError.value = null;

    try {
      if (adminId == null || _authService.currentUser?.id != adminId) {
        throw StateError('An authenticated admin session is required.');
      }

      final profile = await _profileRepository.fetchForUser(adminId);
      if (profile.role != UserRole.admin) {
        throw StateError('Only administrators can view the live officer map.');
      }
      if (revision != _loadRevision || _closed) return;

      if (!_realtimeStarted) {
        _realtimeStarted = true;
        try {
          await _mapRepository.subscribe(
            adminId: adminId,
            onChange: _handleRealtimeChange,
            onConnectionChanged: _handleRealtimeConnection,
          );
        } catch (error, stackTrace) {
          _realtimeStarted = false;
          debugPrint(
            '[AdminLiveMapController] Realtime setup failed; continuing '
            'with the independent initial fetch. error=$error',
          );
          debugPrintStack(
            label: '[AdminLiveMapController] caught Realtime setup stack',
            stackTrace: stackTrace,
          );
          _handleRealtimeConnection(
            false,
            'Realtime setup failed: $error. Initial data is still loading.',
          );
        }
      }

      final results = await Future.wait<dynamic>([
        _profileRepository.fetchOfficers(),
        _mapRepository.fetchLocations(),
        _dutyRepository.fetchActiveDuties(),
      ]);
      if (revision != _loadRevision ||
          _closed ||
          _authService.currentUser?.id != adminId) {
        return;
      }

      final fetchedOfficers = results[0] as List<UserProfile>;
      final fetchedLocations = results[1] as List<OfficerLocation>;
      final officerIds = fetchedOfficers.map((officer) => officer.id).toSet();
      final locationIds =
          fetchedLocations.map((location) => location.officerId).toSet();
      debugPrint(
        '[AdminLiveMapData] profiles=${fetchedOfficers.length} '
        'locations=${fetchedLocations.length} '
        'matchedLocationProfiles=${locationIds.intersection(officerIds).length} '
        'unmatchedLocationIds=${locationIds.difference(officerIds).toList()} '
        'officerIds=${officerIds.toList()} '
        'locationOfficerIds=${locationIds.toList()}.',
      );
      officers.assignAll(fetchedOfficers);
      locations.assignAll({
        for (final location in fetchedLocations)
          location.officerId: location,
      });
      _assignActiveDuties(results[2] as List<DutyModel>);
      _removeUnknownLocations();

      loadState.value = AdminLiveMapLoadState.success;
      clock.value = DateTime.now().toUtc();
      _logLocationClassification('initial map load');
      _freshnessTimer ??= Timer.periodic(
        const Duration(seconds: 20),
        (_) {
          clock.value = DateTime.now().toUtc();
          _logLocationClassification('freshness timer');
        },
      );
    } on PostgrestException catch (error) {
      if (revision != _loadRevision || _closed) return;
      loadError.value = error.code == '42501'
          ? 'Supabase denied access to live map data. Confirm admin SELECT '
              'policies for profiles, duties, and officer_locations.'
          : 'Could not load live map data: ${error.message}';
      loadState.value = AdminLiveMapLoadState.error;
    } catch (error) {
      if (revision != _loadRevision || _closed) return;
      loadError.value = error is StateError
          ? error.message
          : 'Could not load live map data. Check your connection and access.';
      loadState.value = AdminLiveMapLoadState.error;
    } finally {
      _loadInProgress = false;
      _bufferChanges = false;
      if (!_closed && _authService.currentUser?.id == _sessionUserId) {
        _drainBufferedChanges();
      } else {
        _bufferedChanges.clear();
      }
    }
  }

  void selectOfficer(String officerId) {
    selectedOfficerId.value = officerId;
  }

  void clearSelection() {
    selectedOfficerId.value = null;
  }

  void _handleRealtimeConnection(bool connected, String? error) {
    if (_closed) return;
    realtimeConnected.value = connected;
    realtimeError.value = error;
  }

  void _handleRealtimeChange(AdminLiveMapChange change) {
    if (_closed) return;
    if (_bufferChanges) {
      _bufferedChanges.add(change);
      return;
    }
    _applyRealtimeChange(change);
  }

  void _drainBufferedChanges() {
    if (_bufferedChanges.isEmpty) return;
    final changes = List<AdminLiveMapChange>.from(_bufferedChanges);
    _bufferedChanges.clear();
    for (final change in changes) {
      _applyRealtimeChange(change);
    }
  }

  void _applyRealtimeChange(AdminLiveMapChange change) {
    debugPrint(
      '[AdminLiveMapRealtime] Applying change type=${change.type} '
      'officerId=${change.officerId ?? change.location?.officerId}.',
    );
    switch (change.type) {
      case AdminLiveMapChangeType.locationUpdated:
        final location = change.location;
        if (location != null &&
            officers.any((officer) => officer.id == location.officerId)) {
          locations[location.officerId] = location;
          clock.value = DateTime.now().toUtc();
        }
        break;
      case AdminLiveMapChangeType.locationRemoved:
        final officerId = change.officerId;
        if (officerId != null) {
          locations.remove(officerId);
          if (selectedOfficerId.value == officerId) {
            selectedOfficerId.value = null;
          }
        }
        break;
      case AdminLiveMapChangeType.dutiesChanged:
        unawaited(_refreshActiveDuties());
        break;
    }
  }

  Future<void> _refreshActiveDuties() async {
    if (_dutyRefreshInProgress) {
      _dutyRefreshPending = true;
      return;
    }
    _dutyRefreshInProgress = true;
    try {
      do {
        _dutyRefreshPending = false;
        try {
          final result = await _dutyRepository.fetchActiveDuties();
          if (_closed || _authService.currentUser?.id != _sessionUserId) return;
          _assignActiveDuties(result);
        } catch (error) {
          if (error is PostgrestException && error.code == '42501') {
            realtimeError.value =
                'Supabase denied access to active duties. Confirm the admin '
                'SELECT policy for duties.';
          } else {
            realtimeError.value =
                'Live duty details could not be refreshed. Retry the map.';
          }
        }
      } while (_dutyRefreshPending && !_closed);
    } finally {
      _dutyRefreshInProgress = false;
    }
  }

  void _assignActiveDuties(List<DutyModel> duties) {
    final sorted = duties
        .where((duty) => duty.assignedTo != null)
        .toList(growable: true)
      ..sort((first, second) {
        final firstStart = first.startTime;
        final secondStart = second.startTime;
        if (firstStart == null) return 1;
        if (secondStart == null) return -1;
        return secondStart.compareTo(firstStart);
      });

    final grouped = <String, DutyModel>{};
    for (final duty in sorted) {
      grouped.putIfAbsent(duty.assignedTo!, () => duty);
    }
    activeDutiesByOfficer.assignAll(grouped);
  }

  void _removeUnknownLocations() {
    final officerIds = officers.map((officer) => officer.id).toSet();
    final unknownIds = locations.keys
        .where((officerId) => !officerIds.contains(officerId))
        .toList(growable: false);
    debugPrint(
      '[AdminLiveMapData] profile match filter: '
      'knownLocationCount=${locations.length} '
      'unknownLocationIds=$unknownIds.',
    );
    locations.removeWhere((officerId, _) => !officerIds.contains(officerId));
  }

  void _logLocationClassification(String source) {
    final now = clock.value;
    final currentEntries = entries;
    final freshCount = currentEntries
        .where((entry) => entry.isFreshAt(now))
        .length;
    final staleCount = currentEntries
        .where((entry) => entry.hasLocation && !entry.isFreshAt(now))
        .length;
    final missingCount = currentEntries.where((entry) => !entry.hasLocation).length;
    debugPrint(
      '[AdminLiveMapFreshness] source=$source officers=${currentEntries.length} '
      'fresh=$freshCount stale=$staleCount missing=$missingCount '
      'nowUtc=${now.toIso8601String()}.',
    );
    for (final entry in currentEntries.where((item) => item.hasLocation)) {
      final location = entry.location!;
      final age = now.difference(location.updatedAt.toUtc());
      debugPrint(
        '[AdminLiveMapFreshness] officerId=${entry.officer.id} '
        'updatedAtUtc=${location.updatedAt.toUtc().toIso8601String()} '
        'ageSeconds=${age.inSeconds} fresh=${entry.isFreshAt(now)} '
        'coordinates=(${location.latitude},${location.longitude}).',
      );
    }
  }

  void _handleSessionChange(String? userId) {
    if (userId == _sessionUserId) return;
    _sessionUserId = userId;
    _loadRevision++;
    _freshnessTimer?.cancel();
    _freshnessTimer = null;
    _realtimeStarted = false;
    realtimeConnected.value = false;
    realtimeError.value = null;
    officers.clear();
    locations.clear();
    activeDutiesByOfficer.clear();
    selectedOfficerId.value = null;
    _bufferedChanges.clear();
    loadError.value = userId == null
        ? 'Your admin session ended. Return to sign in.'
        : 'The signed-in account changed. Reopen the map from an admin account.';
    loadState.value = AdminLiveMapLoadState.error;
    unawaited(_mapRepository.unsubscribe(
      reason: 'authenticated session changed',
    ));
  }

  @override
  void onClose() {
    _closed = true;
    WidgetsBinding.instance.removeObserver(this);
    _freshnessTimer?.cancel();
    _authSubscription?.cancel();
    unawaited(_mapRepository.unsubscribe(
      reason: 'live map page controller closed',
    ));
    super.onClose();
  }
}
