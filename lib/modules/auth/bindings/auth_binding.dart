import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/auth_service.dart';
import '../../../data/repositories/profile_repository.dart';
import '../controllers/auth_controller.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    final client = Supabase.instance.client;
    Get.put(AuthService(client), permanent: true);
    Get.put(ProfileRepository(client), permanent: true);
    Get.put(AuthController(
      authService: Get.find<AuthService>(),
      profileRepository: Get.find<ProfileRepository>(),
    ), permanent: true);
  }
}
