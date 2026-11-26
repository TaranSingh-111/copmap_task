import 'dart:async';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/auth_service.dart';
import '../../../data/models/duty_model.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/duty_repository.dart';
import '../../../data/repositories/profile_repository.dart';

enum AdminLoadState { loading, success, error }

class AdminController extends GetxController {
  AdminController(this._dutyRepository, this._profileRepository, this._authService);

  final DutyRepository _dutyRepository;
  final ProfileRepository _profileRepository;
  final AuthService _authService;

  final duties = <DutyModel>[].obs;
  final officers = <UserProfile>[].obs;
  final loadState = AdminLoadState.loading.obs;
  final loadError = RxnString();
  final operationError = RxnString();
  final isSaving = false.obs;

  StreamSubscription<AuthState>? _authSubscription;
  String? _adminUserId;
  int _loadRevision = 0;

  int get totalOfficers => officers.length;
  int get totalDuties => duties.length;
  int get pendingDuties => duties
      .where((duty) =>
          duty.status == DutyStatus.pending ||
          duty.status == DutyStatus.assigned)
      .length;
  int get activeDuties =>
      duties.where((duty) => duty.status == DutyStatus.inProgress).length;
  int get completedDuties =>
      duties.where((duty) => duty.status == DutyStatus.completed).length;

  @override
  void onInit() {
    super.onInit();
    _adminUserId = _authService.currentUser?.id;
    _authSubscription = _authService.authStateChanges.listen(
      (event) => _handleUserChange(event.session?.user.id),
    );
    loadDashboard();
  }

  void _handleUserChange(String? userId) {
    if (userId == _adminUserId) return;
    _adminUserId = userId;
    _loadRevision++;
    duties.clear();
    officers.clear();
    loadError.value = null;
    operationError.value = null;
    if (userId == null) {
      loadState.value = AdminLoadState.success;
    } else {
      loadDashboard();
    }
  }

  Future<void> loadDashboard({bool showLoading = true}) async {
    final revision = ++_loadRevision;
    if (showLoading) loadState.value = AdminLoadState.loading;
    loadError.value = null;
    try {
      final results = await Future.wait<dynamic>([
        _dutyRepository.fetchAllDuties(),
        _profileRepository.fetchOfficers(),
      ]);
      if (revision != _loadRevision) return;
      duties.assignAll(results[0] as List<DutyModel>);
      officers.assignAll(results[1] as List<UserProfile>);
      loadState.value = AdminLoadState.success;
    } catch (_) {
      if (revision != _loadRevision) return;
      loadError.value =
          'Could not load dashboard data. Check your connection and access.';
      loadState.value = AdminLoadState.error;
    }
  }

  Future<bool> createDuty(DutyDraft draft) =>
      _runDutyOperation(() => _dutyRepository.createDuty(draft));

  Future<bool> editDuty(DutyModel duty, DutyDraft draft) {
    if (duty.status.isTerminal) {
      operationError.value = 'Completed or cancelled duties cannot be edited.';
      return Future.value(false);
    }
    return _runDutyOperation(
      () => _dutyRepository.updateDuty(existingDuty: duty, draft: draft),
    );
  }

  Future<bool> cancelDuty(DutyModel duty) {
    if (duty.status.isTerminal) {
      operationError.value =
          'Completed or cancelled duties cannot be changed.';
      return Future.value(false);
    }
    return _runDutyOperation(() => _dutyRepository.cancelDuty(duty));
  }

  Future<bool> _runDutyOperation(Future<dynamic> Function() operation) async {
    if (isSaving.value) return false;
    final operationUserId = _adminUserId;
    isSaving.value = true;
    operationError.value = null;
    try {
      await operation();
      if (operationUserId == _adminUserId) {
        await loadDashboard(showLoading: false);
      }
      return true;
    } catch (_) {
      if (operationUserId == _adminUserId) {
        operationError.value =
            'The duty could not be saved. Check your access and try again.';
      }
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  DutyModel? findDuty(String id) {
    for (final duty in duties) {
      if (duty.id == id) return duty;
    }
    return null;
  }

  String officerName(String? id) {
    if (id == null) return 'Unassigned';
    for (final officer in officers) {
      if (officer.id == id) {
        final name = officer.fullName?.trim();
        return name == null || name.isEmpty ? 'Officer $id' : name;
      }
    }
    return 'Officer $id';
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    super.onClose();
  }
}
