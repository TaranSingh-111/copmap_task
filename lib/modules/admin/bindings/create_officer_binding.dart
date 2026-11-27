import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/auth_service.dart';
import '../../../data/repositories/create_officer_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../controllers/admin_controller.dart';
import '../controllers/create_officer_controller.dart';

class CreateOfficerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CreateOfficerRepository>(
      () => CreateOfficerRepository(Supabase.instance.client),
    );
    Get.lazyPut<CreateOfficerController>(
      () => CreateOfficerController(
        Get.find<CreateOfficerRepository>(),
        Get.find<AuthService>(),
        Get.find<ProfileRepository>(),
        Get.find<AdminController>(),
      ),
    );
  }
}
