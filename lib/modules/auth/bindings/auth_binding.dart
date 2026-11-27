import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/officer_location_tracking_service.dart';
import '../../../core/services/officer_location_upload_service.dart';
import '../../../data/repositories/officer_location_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../admin/bindings/admin_binding.dart';
import '../../officer/bindings/duty_binding.dart';
import '../controllers/auth_controller.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    final client = Supabase.instance.client;
    Get.put(AuthService(client), permanent: true);
    Get.put(ProfileRepository(client), permanent: true);
    Get.put(
      OfficerLocationRepository(client),
      permanent: true,
    );
    Get.put(
      OfficerLocationUploadService(
        Get.find<OfficerLocationRepository>(),
      ),
      permanent: true,
    );
    Get.put(
      OfficerLocationTrackingService(
        Get.find<AuthService>(),
        Get.find<OfficerLocationUploadService>(),
      ),
      permanent: true,
    );
    Get.put(AuthController(
      Get.find<AuthService>(),
      Get.find<ProfileRepository>(),
    ), permanent: true);
    DutyBinding().dependencies();
    AdminBinding().dependencies();
  }
}
