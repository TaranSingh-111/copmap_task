import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/user_profile.dart';
import '../controllers/auth_controller.dart';
import '../../admin/views/admin_dashboard_view.dart';
import '../../officer/views/officer_dashboard_view.dart';
import 'login_view.dart';

class AuthGate extends GetView<AuthController> {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      switch (controller.status.value) {
        case AuthStatus.loading:
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        case AuthStatus.signedOut:
          return const LoginView();
        case AuthStatus.signedIn:
          return controller.profile.value?.role == UserRole.admin
              ? const AdminDashboardView()
              : const OfficerDashboardView();
        case AuthStatus.error:
          return _SessionErrorView(
            message: controller.errorMessage.value ??
                'Unable to load your account.',
            onRetry: controller.retrySession,
            onSignOut: controller.signOut,
          );
      }
    });
  }
}

class _SessionErrorView extends StatelessWidget {
  const _SessionErrorView({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
              TextButton(onPressed: onSignOut, child: const Text('Sign out')),
            ],
          ),
        ),
      ),
    );
  }
}
