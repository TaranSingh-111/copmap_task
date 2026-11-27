import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/duty_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/duty_controller.dart';
import 'duty_details_page.dart';
import 'location_tracking_status_card.dart';

class OfficerDashboardView extends GetView<DutyController> {
  const OfficerDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    return Scaffold(
      appBar: AppBar(title: const Text('My duties'), actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: authController.signOut,
          icon: const Icon(Icons.logout),
        ),
      ]),
      body: Obx(() {
        if (controller.loadState.value == DutyLoadState.loading &&
            controller.duties.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.loadState.value == DutyLoadState.error &&
            controller.duties.isEmpty) {
          return _DashboardError(
            message: controller.loadError.value ?? 'Could not load duties.',
            onRetry: controller.loadDuties,
          );
        }
        final duties = controller.duties;
        if (duties.isEmpty) {
          return RefreshIndicator(
            onRefresh: controller.refreshDuties,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 16),
                LocationTrackingStatusCard(),
                SizedBox(height: 16),
                Icon(Icons.assignment_outlined, size: 48),
                SizedBox(height: 12),
                Center(child: Text('No duties are assigned to you yet.')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: controller.refreshDuties,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const LocationTrackingStatusCard(),
              if (controller.loadError.value != null)
                _InlineError(message: controller.loadError.value!),
              _DutySection(title: 'Current', icon: Icons.play_circle_outline,
                  duties: controller.currentDuties),
              _DutySection(title: 'Upcoming', icon: Icons.schedule,
                  duties: controller.upcomingDuties),
              _DutySection(title: 'Completed', icon: Icons.task_alt,
                  duties: controller.completedDuties),
              if (controller.cancelledDuties.isNotEmpty)
                _DutySection(title: 'Cancelled', icon: Icons.cancel_outlined,
                    duties: controller.cancelledDuties),
            ],
          ),
        );
      }),
    );
  }
}

class _DutySection extends StatelessWidget {
  const _DutySection({required this.title, required this.icon,
    required this.duties});
  final String title;
  final IconData icon;
  final List<DutyModel> duties;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(width: 8),
          Text('(${duties.length})'),
        ]),
      ),
      if (duties.isEmpty)
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 2, 8, 8),
          child: Text('No duties in this section.'),
        )
      else
        ...duties.map((duty) => Card(
          child: ListTile(
            title: Text(duty.title),
            subtitle: Text(_subtitle(duty)),
            isThreeLine: duty.description?.isNotEmpty ?? false,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Get.to(() => DutyDetailsPage(duty: duty),
                preventDuplicates: true),
          ),
        )),
    ]),
  );

  String _subtitle(DutyModel duty) {
    final parts = <String>[];
    if (duty.locationName?.isNotEmpty ?? false) parts.add(duty.locationName!);
    if (duty.startTime != null) {
      parts.add(formatDutyDateTime(duty.startTime!));
    }
    if (duty.description?.isNotEmpty ?? false) parts.add(duty.description!);
    return parts.isEmpty ? 'No additional details' : parts.join(' • ');
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(message,
        style: TextStyle(color: Theme.of(context).colorScheme.error)),
  );
}
