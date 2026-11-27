import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/officer_location_tracking_service.dart';
import '../../../data/repositories/duty_repository.dart';
import '../controllers/duty_controller.dart';

class DutyBinding extends Bindings {
  @override
  void dependencies() {
    final client = Supabase.instance.client;
    Get.lazyPut<DutyRepository>(() => DutyRepository(client), fenix: true);
    Get.lazyPut<DutyController>(
      () => DutyController(
        Get.find<DutyRepository>(),
        Get.find<AuthService>(),
        Get.find<OfficerLocationTrackingService>(),
      ),
      fenix: true,
    );
  }
}
