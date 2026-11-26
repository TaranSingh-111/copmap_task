import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/duty_model.dart';
import '../controllers/admin_controller.dart';
import 'duty_form_page.dart';

class AdminDutyDetailsPage extends GetView<AdminController> {
  const AdminDutyDetailsPage({required this.duty, super.key});

  final DutyModel duty;

  @override
  Widget build(BuildContext context) => Obx(() {
    final currentDuty = controller.findDuty(duty.id) ?? duty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duty details'),
        actions: [
          if (!currentDuty.status.isTerminal)
            IconButton(
              tooltip: 'Edit duty',
              onPressed: controller.isSaving.value
                  ? null
                  : () => Get.to(() => DutyFormPage(duty: currentDuty)),
              icon: const Icon(Icons.edit),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(currentDuty.title,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          _DetailRow(label: 'Status', value: _statusLabel(currentDuty.status)),
          _DetailRow(
            label: 'Officer',
            value: controller.officerName(currentDuty.assignedTo),
          ),
          if (currentDuty.locationName?.isNotEmpty == true)
            _DetailRow(label: 'Location', value: currentDuty.locationName!),
          if (currentDuty.latitude != null && currentDuty.longitude != null)
            _DetailRow(
              label: 'Coordinates',
              value: '${currentDuty.latitude}, ${currentDuty.longitude}',
            ),
          if (currentDuty.startTime != null)
            _DetailRow(label: 'Starts',
                value: formatDutyDateTime(currentDuty.startTime!)),
          if (currentDuty.endTime != null)
            _DetailRow(label: 'Ends',
                value: formatDutyDateTime(currentDuty.endTime!)),
          if (currentDuty.description?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Text('Description',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(currentDuty.description!),
          ],
          const SizedBox(height: 24),
          Obx(() {
            final error = controller.operationError.value;
            if (error == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            );
          }),
          if (!currentDuty.status.isTerminal)
            Obx(() => OutlinedButton.icon(
              onPressed: controller.isSaving.value
                  ? null
                  : () => _confirmCancel(context, currentDuty),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel duty'),
            )),
        ],
      ),
    );
  });

  Future<void> _confirmCancel(BuildContext context, DutyModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel duty?'),
        content: const Text('This duty will be marked as cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep duty'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel duty'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.cancelDuty(item);
  }

  String _statusLabel(DutyStatus status) => switch (status) {
    DutyStatus.pending => 'Pending',
    DutyStatus.assigned => 'Assigned',
    DutyStatus.inProgress => 'In progress',
    DutyStatus.completed => 'Completed',
    DutyStatus.cancelled => 'Cancelled',
  };
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 100,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
      Expanded(child: Text(value)),
    ]),
  );
}
