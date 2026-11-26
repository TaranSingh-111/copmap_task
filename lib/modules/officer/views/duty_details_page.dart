import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/duty_model.dart';
import '../controllers/duty_controller.dart';

class DutyDetailsPage extends GetView<DutyController> {
  const DutyDetailsPage({required this.duty, super.key});
  final DutyModel duty;

  @override
  Widget build(BuildContext context) => Obx(() {
    final currentDuty = controller.findDuty(duty.id) ?? duty;
    return Scaffold(
      appBar: AppBar(title: const Text('Duty details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(currentDuty.title,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          _DetailRow(label: 'Status', value: _statusLabel(currentDuty.status)),
          if (currentDuty.locationName?.isNotEmpty ?? false)
            _DetailRow(label: 'Location', value: currentDuty.locationName!),
          if (currentDuty.startTime != null)
            _DetailRow(label: 'Starts',
                value: formatDutyDateTime(currentDuty.startTime!)),
          if (currentDuty.endTime != null)
            _DetailRow(label: 'Ends',
                value: formatDutyDateTime(currentDuty.endTime!)),
          if (currentDuty.description?.isNotEmpty ?? false) ...[
            const SizedBox(height: 16),
            Text('Instructions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(currentDuty.description!),
          ],
          const SizedBox(height: 24),
          Obx(() {
            final error = controller.actionError.value;
            if (error == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            );
          }),
          if (currentDuty.canStart)
            _actionButton('Start duty', currentDuty, DutyStatus.inProgress),
          if (currentDuty.canComplete)
            _actionButton('Complete duty', currentDuty, DutyStatus.completed),
        ],
      ),
    );
  });

  Widget _actionButton(String label, DutyModel item, DutyStatus targetStatus) =>
      Obx(() {
        final busy = controller.activeActionDutyId.value == item.id;
        return FilledButton(
          onPressed: busy ? null : () => targetStatus == DutyStatus.inProgress
              ? controller.startDuty(item) : controller.completeDuty(item),
          child: busy
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(label),
        );
      });

  static String _statusLabel(DutyStatus status) => switch (status) {
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
      SizedBox(width: 88,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
      Expanded(child: Text(value)),
    ]),
  );
}
