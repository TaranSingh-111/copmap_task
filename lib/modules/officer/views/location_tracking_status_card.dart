import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/officer_location_tracking_service.dart';
import '../../../core/services/officer_location_upload_service.dart';

class LocationTrackingStatusCard extends StatelessWidget {
  const LocationTrackingStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final tracking = Get.find<OfficerLocationTrackingService>();
    final uploader = Get.find<OfficerLocationUploadService>();
    return Obx(() {
      final status = tracking.status.value;
      final uploadState = uploader.uploadState.value;
      final message = tracking.message.value;
      final isActive = status == LocationTrackingStatus.tracking ||
          status == LocationTrackingStatus.foregroundOnly;
      final statusColor = switch (status) {
        LocationTrackingStatus.tracking => AppColors.success,
        LocationTrackingStatus.foregroundOnly ||
        LocationTrackingStatus.foregroundPermissionDenied ||
        LocationTrackingStatus.backgroundPermissionPermanentlyDenied ||
        LocationTrackingStatus.locationDisabled => AppColors.warning,
        LocationTrackingStatus.error ||
        LocationTrackingStatus.foregroundPermissionPermanentlyDenied =>
          AppColors.error,
        LocationTrackingStatus.checking => AppColors.accent,
        LocationTrackingStatus.idle => AppColors.secondaryText,
      };
      final uploadColor = switch (uploadState) {
        LocationUploadState.uploaded => AppColors.success,
        LocationUploadState.retrying => AppColors.error,
        LocationUploadState.uploading => AppColors.accent,
        LocationUploadState.idle => statusColor,
      };
      final title = switch (status) {
        LocationTrackingStatus.idle => 'Location sharing is off',
        LocationTrackingStatus.checking => 'Checking location access…',
        LocationTrackingStatus.tracking => 'Location sharing is active',
        LocationTrackingStatus.foregroundOnly =>
          'Location sharing is active in the foreground',
        LocationTrackingStatus.foregroundPermissionDenied =>
          'Location permission is needed',
        LocationTrackingStatus.foregroundPermissionPermanentlyDenied =>
          'Location permission is blocked',
        LocationTrackingStatus.backgroundPermissionPermanentlyDenied =>
          'Background location is blocked',
        LocationTrackingStatus.locationDisabled => 'Location services are off',
        LocationTrackingStatus.error => 'Location sharing needs attention',
      };
      final icon = switch (status) {
        LocationTrackingStatus.tracking => Icons.gps_fixed,
        LocationTrackingStatus.foregroundOnly => Icons.gps_not_fixed,
        LocationTrackingStatus.checking => Icons.location_searching,
        LocationTrackingStatus.locationDisabled => Icons.location_disabled,
        LocationTrackingStatus.error ||
        LocationTrackingStatus.foregroundPermissionDenied ||
        LocationTrackingStatus.foregroundPermissionPermanentlyDenied ||
        LocationTrackingStatus.backgroundPermissionPermanentlyDenied =>
          Icons.warning_amber_rounded,
        LocationTrackingStatus.idle => Icons.location_off_outlined,
      };
      final uploadMessage = switch (uploadState) {
        LocationUploadState.uploading => 'Uploading latest location…',
        LocationUploadState.retrying =>
          uploader.uploadError.value ?? 'Upload is retrying automatically.',
        LocationUploadState.uploaded => 'Latest location uploaded',
        LocationUploadState.idle => null,
      };
      final canRequestBackground = isActive &&
          status !=
              LocationTrackingStatus.backgroundPermissionPermanentlyDenied &&
          !tracking.backgroundPermissionGranted.value &&
          tracking.backgroundTrackingSupported;
      final canOpenAppSettings =
          status == LocationTrackingStatus.foregroundPermissionPermanentlyDenied ||
              status ==
                  LocationTrackingStatus.backgroundPermissionPermanentlyDenied;

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  if (message != null) ...[
                    const SizedBox(height: 5),
                    Text(message),
                  ],
                ]),
              ),
            ]),
            if (tracking.isApproximate.value && isActive) ...[
              const SizedBox(height: 8),
              const Text(
                'Approximate location is enabled. Your shared position may be less precise.',
              ),
            ],
            if (tracking.notificationPermissionDenied.value &&
                tracking.backgroundTrackingSupported) ...[
              const SizedBox(height: 8),
              const Text(
                'Notifications are disabled. Android may still show the location service notification in system controls.',
              ),
            ],
            if (uploadMessage != null) ...[
              const SizedBox(height: 8),
              Text(uploadMessage, style: TextStyle(color: uploadColor)),
            ],
            if (canRequestBackground || canOpenAppSettings ||
                status == LocationTrackingStatus.locationDisabled ||
                status == LocationTrackingStatus.error ||
                status == LocationTrackingStatus.foregroundPermissionDenied ||
                uploadState == LocationUploadState.retrying) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 4, children: [
                if (canRequestBackground)
                  OutlinedButton(
                    onPressed: () => _explainBackgroundPermission(
                      context,
                      tracking,
                    ),
                    child: const Text('Enable background location'),
                  ),
                if (canOpenAppSettings)
                  OutlinedButton(
                    onPressed: tracking.openAppSettingsPage,
                    child: const Text('Open app settings'),
                  ),
                if (status == LocationTrackingStatus.locationDisabled)
                  OutlinedButton(
                    onPressed: tracking.openLocationSettingsPage,
                    child: const Text('Turn on location'),
                  ),
                if (status == LocationTrackingStatus.error ||
                    status == LocationTrackingStatus.foregroundPermissionDenied)
                  OutlinedButton(
                    onPressed: tracking.retryTracking,
                    child: const Text('Retry'),
                  ),
                if (uploadState == LocationUploadState.retrying)
                  TextButton(
                    onPressed: uploader.retryNow,
                    child: const Text('Retry upload'),
                  ),
              ]),
            ],
          ]),
        ),
      );
    });
  }

  Future<void> _explainBackgroundPermission(
    BuildContext context,
    OfficerLocationTrackingService tracking,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow background location?'),
        content: const Text(
          'CopMap shares your location only while you have an active duty. '
          'Allow background location so sharing can continue more reliably '
          'when you switch apps or lock your phone. If you skip this, tracking '
          'may only work while CopMap is open.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (approved == true) await tracking.requestBackgroundPermission();
  }
}
