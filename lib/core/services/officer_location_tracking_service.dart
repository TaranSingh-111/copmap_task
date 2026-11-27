import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/duty_model.dart';
import '../../data/models/officer_location.dart';
import 'auth_service.dart';
import 'officer_location_upload_service.dart';

enum LocationTrackingStatus {
  idle,
  checking,
  tracking,
  foregroundOnly,
  foregroundPermissionDenied,
  foregroundPermissionPermanentlyDenied,
  backgroundPermissionPermanentlyDenied,
  locationDisabled,
  error,
}

class OfficerLocationTrackingService extends GetxService {
  OfficerLocationTrackingService(this._authService, this._uploadService);

  final AuthService _authService;
  final OfficerLocationUploadService _uploadService;

  final status = LocationTrackingStatus.idle.obs;
  final message = RxnString();
  final isApproximate = false.obs;
  final notificationPermissionDenied = false.obs;
  final backgroundPermissionGranted = false.obs;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  String? _officerId;
  Future<void> _operationQueue = Future<void>.value();

  bool get isTracking => _positionSubscription != null;
  bool get backgroundTrackingSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  @override
  void onInit() {
    super.onInit();
    _authSubscription = _authService.authStateChanges.listen((event) {
      final sessionUserId = event.session?.user.id;
      if (_officerId != null && sessionUserId != _officerId) {
        unawaited(stopTracking());
      }
    });
  }

  Future<void> reconcile({
    required String? officerId,
    required List<DutyModel> duties,
  }) {
    final hasActiveDuty = duties.any(
      (duty) => duty.status == DutyStatus.inProgress,
    );
    return _enqueue(() async {
      if (officerId == null || !hasActiveDuty) {
        await _stopInternal();
        return;
      }
      if (_officerId == officerId && _positionSubscription != null) return;
      if (_officerId == officerId &&
          status.value != LocationTrackingStatus.idle) {
        // Keep permission/GPS errors stable until the user explicitly retries.
        return;
      }
      await _stopInternal();
      await _startInternal(officerId);
    });
  }

  Future<void> retryTracking() {
    final officerId = _officerId;
    if (officerId == null) return Future<void>.value();
    return _enqueue(() async {
      await _stopPositionSubscription();
      await _startInternal(officerId);
    });
  }

  Future<void> onAppResumed() {
    final officerId = _officerId;
    if (officerId == null) return Future<void>.value();
    return _enqueue(() async {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await _stopPositionSubscription();
        await _uploadService.stopSession(officerId);
        status.value = LocationTrackingStatus.locationDisabled;
        message.value = 'Turn on GPS/location services to resume sharing.';
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        await _stopPositionSubscription();
        await _uploadService.stopSession(officerId);
        status.value =
            LocationTrackingStatus.foregroundPermissionPermanentlyDenied;
        message.value =
            'Location permission is blocked. Allow it in app settings to resume tracking.';
        return;
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        await _stopPositionSubscription();
        await _uploadService.stopSession(officerId);
        status.value = LocationTrackingStatus.foregroundPermissionDenied;
        message.value =
            'Allow location while using CopMap to resume sharing during duty.';
        return;
      }

      PermissionStatus? backgroundStatus;
      if (defaultTargetPlatform == TargetPlatform.android) {
        backgroundStatus = await Permission.locationAlways.status;
        backgroundPermissionGranted.value =
            backgroundStatus == PermissionStatus.granted;
      }

      if (_positionSubscription == null) {
        await _listenForPositions(
          officerId,
          useForegroundService:
              defaultTargetPlatform == TargetPlatform.android,
        );
      }
      if (_positionSubscription == null) return;

      if (backgroundStatus == PermissionStatus.permanentlyDenied) {
        status.value =
            LocationTrackingStatus.backgroundPermissionPermanentlyDenied;
        message.value =
            'Background location is blocked. Sharing may only work while CopMap is open.';
      } else if (backgroundTrackingSupported &&
          !backgroundPermissionGranted.value) {
        status.value = LocationTrackingStatus.foregroundOnly;
        message.value =
            'Location sharing is active with an Android foreground notification. Without background location permission, updates may only work while CopMap is open.';
      } else {
        status.value = LocationTrackingStatus.tracking;
        message.value = null;
      }
    });
  }

  Future<void> requestBackgroundPermission() {
    final officerId = _officerId;
    if (officerId == null ||
        defaultTargetPlatform != TargetPlatform.android) {
      return Future<void>.value();
    }

    return _enqueue(() async {
      final foreground = await Geolocator.checkPermission();
      if (foreground != LocationPermission.whileInUse &&
          foreground != LocationPermission.always) {
        await _startInternal(officerId);
        return;
      }

      try {
        final result = await Permission.locationAlways.request();
        backgroundPermissionGranted.value =
            result == PermissionStatus.granted;
        if (result == PermissionStatus.granted) {
          await _stopPositionSubscription();
          await _listenForPositions(officerId, useForegroundService: true);
        } else {
          if (result == PermissionStatus.permanentlyDenied) {
            status.value =
                LocationTrackingStatus.backgroundPermissionPermanentlyDenied;
            message.value =
                'Background location is blocked. You can still share while the app is open.';
          } else {
            status.value = LocationTrackingStatus.foregroundOnly;
            message.value =
                'Background permission was not granted. Location may stop when the app is closed.';
          }
        }
      } catch (_) {
        status.value = LocationTrackingStatus.foregroundOnly;
        message.value =
            'Background permission could not be checked. Location may stop when the app is closed.';
      }
    });
  }

  Future<void> openAppSettingsPage() async {
    await Geolocator.openAppSettings();
  }

  Future<void> openLocationSettingsPage() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> stopTracking() =>
      _enqueue(_stopInternal);

  Future<void> _startInternal(String officerId) async {
    _officerId = officerId;
    status.value = LocationTrackingStatus.checking;
    message.value = null;

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        status.value =
            LocationTrackingStatus.foregroundPermissionPermanentlyDenied;
        message.value =
            'Location permission is blocked. Allow it in app settings to start tracking.';
        return;
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        status.value = LocationTrackingStatus.foregroundPermissionDenied;
        message.value =
            'Allow location while using CopMap to share during an active duty.';
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        status.value = LocationTrackingStatus.locationDisabled;
        message.value = 'Turn on GPS/location services to share your location.';
        return;
      }

      try {
        isApproximate.value =
            await Geolocator.getLocationAccuracy() ==
                LocationAccuracyStatus.reduced;
      } catch (_) {
        isApproximate.value = false;
      }

      var useForegroundService = false;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final alwaysPermission = await Permission.locationAlways.status;
        backgroundPermissionGranted.value =
            alwaysPermission == PermissionStatus.granted;
        // Start the foreground service while the app is visible. Granting
        // "Allow all the time" is still recommended for more reliable background
        // operation, and the UI reports when that access is unavailable.
        useForegroundService = true;

        final notificationPermission = await Permission.notification.status;
        if (notificationPermission != PermissionStatus.granted) {
          final requested = await Permission.notification.request();
          notificationPermissionDenied.value =
              requested != PermissionStatus.granted;
        } else {
          notificationPermissionDenied.value = false;
        }
      }

      _uploadService.activate(officerId);
      await _listenForPositions(
        officerId,
        useForegroundService: useForegroundService,
      );
    } on LocationServiceDisabledException {
      status.value = LocationTrackingStatus.locationDisabled;
      message.value = 'Turn on GPS/location services to share your location.';
    } on PermissionDeniedException {
      status.value = LocationTrackingStatus.foregroundPermissionDenied;
      message.value = 'Location permission is required during an active duty.';
    } catch (_) {
      status.value = LocationTrackingStatus.error;
      message.value = 'Location tracking could not start. Please retry.';
    }
  }

  Future<void> _listenForPositions(
    String officerId, {
    required bool useForegroundService,
  }) async {
    final settings = _locationSettings(useForegroundService);
    try {
      _uploadService.activate(officerId);
      final stream = Geolocator.getPositionStream(locationSettings: settings);
      _positionSubscription = stream.listen(
        (position) => _onPosition(officerId, position),
        onError: (Object error) => _onPositionError(officerId, error),
      );
      final hasBackgroundAccess =
          !backgroundTrackingSupported || backgroundPermissionGranted.value;
      status.value = hasBackgroundAccess
          ? LocationTrackingStatus.tracking
          : LocationTrackingStatus.foregroundOnly;
      if (hasBackgroundAccess) {
        message.value = null;
      } else {
        message.value =
            'Location sharing is active with an Android foreground notification. Without background location permission, updates may only work while CopMap is open.';
      }
    } catch (_) {
      status.value = LocationTrackingStatus.error;
      message.value = 'Could not start the GPS update stream. Please retry.';
      await _stopPositionSubscription();
    }
  }

  LocationSettings _locationSettings(bool useForegroundService) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: useForegroundService
            ? const ForegroundNotificationConfig(
                notificationTitle: 'CopMap location sharing',
                notificationText:
                    'Your location is shared while you have an active duty.',
                notificationChannelName: 'Officer location',
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
    );
  }

  void _onPosition(String officerId, Position position) {
    if (_officerId != officerId) return;
    _uploadService.enqueue(
      OfficerLocation(
        officerId: officerId,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  void _onPositionError(String officerId, Object error) {
    unawaited(_enqueue(() async {
      if (_officerId != officerId) return;
      await _stopPositionSubscription();
      await _uploadService.stopSession(officerId);
      if (error is LocationServiceDisabledException) {
        status.value = LocationTrackingStatus.locationDisabled;
        message.value = 'Turn on GPS/location services to resume sharing.';
      } else if (error is PermissionDeniedException) {
        status.value = LocationTrackingStatus.foregroundPermissionDenied;
        message.value = 'Location permission was revoked. Allow it to resume.';
      } else {
        status.value = LocationTrackingStatus.error;
        message.value = 'GPS updates stopped. Retry tracking to reconnect.';
      }
    }));
  }

  Future<void> _stopPositionSubscription() async {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();
  }

  Future<void> _stopInternal() async {
    final officerId = _officerId;
    _officerId = null;
    await _stopPositionSubscription();
    if (officerId != null) await _uploadService.stopSession(officerId);
    backgroundPermissionGranted.value = false;
    isApproximate.value = false;
    notificationPermissionDenied.value = false;
    message.value = null;
    status.value = LocationTrackingStatus.idle;
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _operationQueue.then((_) => operation());
    _operationQueue = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    unawaited(stopTracking());
    super.onClose();
  }
}
