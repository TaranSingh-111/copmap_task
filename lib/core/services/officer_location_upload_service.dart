import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/models/officer_location.dart';
import '../../data/repositories/officer_location_repository.dart';

enum LocationUploadState { idle, uploading, retrying, uploaded }

class OfficerLocationUploadService extends GetxService {
  OfficerLocationUploadService(this._repository);

  final OfficerLocationRepository _repository;
  final uploadState = LocationUploadState.idle.obs;
  final uploadError = RxnString();

  String? _officerId;
  OfficerLocation? _pendingLocation;
  Timer? _retryTimer;
  bool _uploading = false;
  int _sessionRevision = 0;
  int _retryAttempt = 0;

  void activate(String officerId) {
    if (_officerId == officerId) return;
    debugPrint(
      '[OfficerLocationUpload] Upload session activated for officerId=$officerId.',
    );
    _sessionRevision++;
    _retryTimer?.cancel();
    _retryTimer = null;
    _officerId = officerId;
    _pendingLocation = null;
    _retryAttempt = 0;
    uploadError.value = null;
    uploadState.value = LocationUploadState.idle;
  }

  void enqueue(OfficerLocation location) {
    if (_officerId != location.officerId) {
      debugPrint(
        '[OfficerLocationUpload] STAGE 4 DROPPED: upload service invoked '
        'for officerId=${location.officerId}, but active session is $_officerId.',
      );
      return;
    }
    debugPrint(
      '[OfficerLocationUpload] STAGE 4: upload service invoked '
      'officerId=${location.officerId} '
      'latitude=${location.latitude} longitude=${location.longitude} '
      'accuracy=${location.accuracy} updatedAt=${location.updatedAt.toIso8601String()}.',
    );
    _pendingLocation = location;
    if (_retryTimer == null) unawaited(_flush());
  }

  void retryNow() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    if (_pendingLocation != null) unawaited(_flush());
  }

  Future<void> stopSession(String officerId) async {
    if (_officerId != officerId) return;
    _sessionRevision++;
    _officerId = null;
    _pendingLocation = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    uploadError.value = null;
    uploadState.value = LocationUploadState.idle;
  }

  Future<void> _flush() async {
    if (_uploading || _pendingLocation == null || _officerId == null) return;

    _uploading = true;
    final revision = _sessionRevision;
    final location = _pendingLocation!;
    uploadState.value = LocationUploadState.uploading;
    debugPrint(
      '[OfficerLocationUpload] Repository upload invoked '
      'officerId=${location.officerId} sessionRevision=$revision.',
    );
    try {
      await _repository.upsertLocation(location);
      debugPrint(
        '[OfficerLocationUpload] Repository upload completed '
        'officerId=${location.officerId} sessionRevision=$revision.',
      );
      if (revision != _sessionRevision) return;
      if (identical(_pendingLocation, location)) _pendingLocation = null;
      _retryAttempt = 0;
      uploadError.value = null;
      uploadState.value = LocationUploadState.uploaded;
    } catch (error, stackTrace) {
      debugPrint(
        '[OfficerLocationUpload] Repository upload failed '
        'officerId=${location.officerId} error=$error',
      );
      debugPrintStack(
        label: '[OfficerLocationUpload] upload failure stack',
        stackTrace: stackTrace,
      );
      if (revision != _sessionRevision) return;
      uploadError.value = 'Location upload failed. Retrying automatically.';
      uploadState.value = LocationUploadState.retrying;
      _scheduleRetry(revision);
    } finally {
      _uploading = false;
      if (revision != _sessionRevision && _pendingLocation != null) {
        unawaited(_flush());
      } else if (revision == _sessionRevision &&
          _pendingLocation != null &&
          _retryTimer == null) {
        unawaited(_flush());
      }
    }
  }

  void _scheduleRetry(int revision) {
    _retryAttempt++;
    final seconds = 1 << (_retryAttempt.clamp(1, 6) - 1);
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), () {
      _retryTimer = null;
      if (revision == _sessionRevision) unawaited(_flush());
    });
  }

  @override
  void onClose() {
    _retryTimer?.cancel();
    super.onClose();
  }
}
