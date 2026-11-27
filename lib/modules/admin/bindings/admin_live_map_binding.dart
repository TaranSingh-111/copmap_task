import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/auth_service.dart';
import '../../../data/repositories/admin_live_map_repository.dart';
import '../../../data/repositories/duty_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../controllers/admin_live_map_controller.dart';

class AdminLiveMapBinding extends Bindings {
  @override
  void dependencies() {
    final client = Supabase.instance.client;
    Get.lazyPut<AdminLiveMapRepository>(
      () => AdminLiveMapRepository(client),
    );
    Get.lazyPut<AdminLiveMapController>(
      () => AdminLiveMapController(
        Get.find<AuthService>(),
        Get.find<ProfileRepository>(),
        Get.find<DutyRepository>(),
        Get.find<AdminLiveMapRepository>(),
      ),
    );
  }
}
