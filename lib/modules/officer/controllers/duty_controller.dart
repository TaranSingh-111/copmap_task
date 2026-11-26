import 'dart:async';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/auth_service.dart';
import '../../../data/models/duty_model.dart';
import '../../../data/repositories/duty_repository.dart';

enum DutyLoadState { loading, success, error }

class DutyController extends GetxController {
  DutyController(this._repository, this._authService);

  final DutyRepository _repository;
  final AuthService _authService;
  final duties = <DutyModel>[].obs;
  final loadState = DutyLoadState.loading.obs;
  final loadError = RxnString();
  final actionError = RxnString();
  final activeActionDutyId = RxnString();
  StreamSubscription<AuthState>? _authSubscription;
  String? _currentUserId;
  int _requestRevision = 0;

  List<DutyModel> get currentDuties => duties
      .where((duty) => duty.status == DutyStatus.inProgress).toList();
  List<DutyModel> get upcomingDuties => duties
      .where((duty) => duty.status == DutyStatus.pending ||
          duty.status == DutyStatus.assigned).toList();
  List<DutyModel> get completedDuties => duties
      .where((duty) => duty.status == DutyStatus.completed).toList();
  List<DutyModel> get cancelledDuties => duties
      .where((duty) => duty.status == DutyStatus.cancelled).toList();

  @override
  void onInit() {
    super.onInit();
    _currentUserId = _authService.currentUser?.id;
    _authSubscription = _authService.authStateChanges.listen(
      (event) => _handleUserChange(event.session?.user.id),
    );
    loadDuties();
  }

  void _handleUserChange(String? userId) {
    if (userId == _currentUserId) return;
    _currentUserId = userId;
    _requestRevision++;
    duties.clear();
    loadError.value = null;
    actionError.value = null;
    if (userId == null) {
      loadState.value = DutyLoadState.success;
    } else {
      loadDuties();
    }
  }

  Future<void> loadDuties() async {
    final revision = ++_requestRevision;
    loadState.value = DutyLoadState.loading;
    loadError.value = null;
    try {
      final result = await _repository.fetchAssignedDuties();
      if (revision != _requestRevision) return;
      duties.assignAll(result);
      loadState.value = DutyLoadState.success;
    } catch (_) {
      if (revision != _requestRevision) return;
      loadError.value = 'Could not load your duties. Pull to refresh or retry.';
      loadState.value = DutyLoadState.error;
    }
  }

  Future<void> refreshDuties() async {
    final revision = ++_requestRevision;
    loadError.value = null;
    try {
      final result = await _repository.fetchAssignedDuties();
      if (revision != _requestRevision) return;
      duties.assignAll(result);
      loadState.value = DutyLoadState.success;
    } catch (_) {
      if (revision != _requestRevision) return;
      loadError.value = 'Could not refresh your duties. Please try again.';
      if (duties.isEmpty) loadState.value = DutyLoadState.error;
    }
  }

  Future<bool> startDuty(DutyModel duty) =>
      _transition(duty, DutyStatus.inProgress);
  Future<bool> completeDuty(DutyModel duty) =>
      _transition(duty, DutyStatus.completed);

  DutyModel? findDuty(String dutyId) {
    for (final duty in duties) {
      if (duty.id == dutyId) return duty;
    }
    return null;
  }

  Future<bool> _transition(DutyModel duty, DutyStatus newStatus) async {
    if (activeActionDutyId.value != null) return false;
    final currentDuty = findDuty(duty.id);
    final transitionAllowed = currentDuty != null &&
        ((newStatus == DutyStatus.inProgress && currentDuty.canStart) ||
            (newStatus == DutyStatus.completed && currentDuty.canComplete));
    if (!transitionAllowed) {
      actionError.value = 'This duty is no longer available for that action.';
      return false;
    }

    final actionUserId = _currentUserId;
    actionError.value = null;
    activeActionDutyId.value = duty.id;
    try {
      await _repository.transitionStatus(dutyId: duty.id, newStatus: newStatus);
      if (actionUserId != _currentUserId) return false;

      final index = duties.indexWhere((item) => item.id == duty.id);
      if (index >= 0) duties[index] = currentDuty.copyWith(status: newStatus);
      await refreshDuties();
      if (actionUserId == _currentUserId && loadError.value != null) {
        actionError.value =
            'Duty status was updated, but the list could not be refreshed.';
      }
      return true;
    } catch (_) {
      if (actionUserId == _currentUserId) {
        actionError.value =
            'The duty status could not be changed. It may have been updated already.';
      }
      return false;
    } finally {
      if (activeActionDutyId.value == duty.id) {
        activeActionDutyId.value = null;
      }
    }
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    super.onClose();
  }
}
