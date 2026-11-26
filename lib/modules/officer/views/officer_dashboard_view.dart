import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../auth/controllers/auth_controller.dart';

class OfficerDashboardView extends GetView<AuthController> {
  const OfficerDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer dashboard'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: controller.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const Center(child: Text('Officer dashboard coming soon')),
    );
  }
}
