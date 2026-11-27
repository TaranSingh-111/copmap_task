import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../../../data/models/duty_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../bindings/admin_live_map_binding.dart';
import '../bindings/create_officer_binding.dart';
import '../controllers/admin_controller.dart';
import 'admin_duty_details_page.dart';
import 'admin_live_map_page.dart';
import 'create_officer_page.dart';
import 'duty_form_page.dart';

class AdminDashboardView extends GetView<AdminController> {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin dashboard'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: authController.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.to(() => const DutyFormPage()),
        icon: const Icon(Icons.add),
        label: const Text('Create duty'),
      ),
      body: Obx(() {
        if (controller.loadState.value == AdminLoadState.loading &&
            controller.duties.isEmpty &&
            controller.officers.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.loadState.value == AdminLoadState.error &&
            controller.duties.isEmpty &&
            controller.officers.isEmpty) {
          return _ErrorState(
            message: controller.loadError.value ?? 'Could not load dashboard.',
            onRetry: controller.loadDashboard,
          );
        }

        return RefreshIndicator(
          onRefresh: controller.loadDashboard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (controller.loadError.value != null)
                _InlineMessage(message: controller.loadError.value!),
              Text('Overview', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetricCard(label: 'Officers', value: controller.totalOfficers,
                      icon: Icons.people_outline),
                  _MetricCard(label: 'Total duties', value: controller.totalDuties,
                      icon: Icons.assignment_outlined),
                  _MetricCard(label: 'Pending', value: controller.pendingDuties,
                      icon: Icons.schedule),
                  _MetricCard(label: 'Active', value: controller.activeDuties,
                      icon: Icons.play_circle_outline),
                  _MetricCard(label: 'Completed',
                      value: controller.completedDuties, icon: Icons.task_alt),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('Live officer map'),
                  subtitle: const Text(
                    'View current officer locations and active duties',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Get.to(
                    () => const AdminLiveMapPage(),
                    binding: AdminLiveMapBinding(),
                    preventDuplicates: true,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text('Duties',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                ],
              ),
              if (controller.duties.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No duties have been created yet.')),
                )
              else
                ...controller.duties.map((duty) => Card(
                  child: ListTile(
                    title: Text(duty.title),
                    subtitle: Text(
                      _dutySubtitle(duty, controller.officerName(duty.assignedTo)),
                    ),
                    trailing: _StatusChip(status: duty.status),
                    onTap: () => Get.to(
                      () => AdminDutyDetailsPage(duty: duty),
                    ),
                  ),
                )),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Officers',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Get.to(
                      () => const CreateOfficerPage(),
                      binding: CreateOfficerBinding(),
                      preventDuplicates: true,
                    ),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Create Officer'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (controller.officers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No officer profiles are available.'),
                )
              else
                ...controller.officers.map((officer) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text(
                    officer.fullName?.trim().isNotEmpty == true
                        ? officer.fullName!.trim()
                        : 'Officer ${officer.id}',
                  ),
                  subtitle: Text(
                    officer.createdAt == null
                        ? 'Officer'
                        : 'Officer • Joined ${formatDutyDateTime(officer.createdAt!)}',
                  ),
                )),
            ],
          ),
        );
      }),
    );
  }

  String _dutySubtitle(DutyModel duty, String officerName) {
    final parts = <String>[officerName];
    if (duty.locationName?.trim().isNotEmpty == true) {
      parts.add(duty.locationName!.trim());
    }
    if (duty.startTime != null) {
      parts.add(formatDutyDateTime(duty.startTime!));
    }
    return parts.join(' • ');
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 156,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon),
          const SizedBox(height: 12),
          Text(value.toString(),
              style: Theme.of(context).textTheme.headlineSmall),
          Text(label),
        ]),
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final DutyStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      DutyStatus.pending => 'PENDING',
      DutyStatus.assigned => 'ASSIGNED',
      DutyStatus.inProgress => 'IN PROGRESS',
      DutyStatus.completed => 'COMPLETED',
      DutyStatus.cancelled => 'CANCELLED',
    };
    final color = switch (status) {
      DutyStatus.pending => AppColors.warning,
      DutyStatus.assigned => AppColors.secondary,
      DutyStatus.inProgress => AppColors.accent,
      DutyStatus.completed => AppColors.success,
      DutyStatus.cancelled => AppColors.error,
    };
    return Chip(
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      label: Text(label, style: TextStyle(color: color)),
      visualDensity: VisualDensity.compact,
    );
  }
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

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(message, style: TextStyle(color: AppColors.error)),
  );
}
