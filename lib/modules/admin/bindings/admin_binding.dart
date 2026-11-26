import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../data/repositories/duty_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../controllers/admin_controller.dart';

class AdminBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AdminController>(
      () => AdminController(
        Get.find<DutyRepository>(),
        Get.find<ProfileRepository>(),
        Get.find<AuthService>(),
      ),
      fenix: true,
    );
  }
}
