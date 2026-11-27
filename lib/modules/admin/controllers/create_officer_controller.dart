import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/create_officer_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import 'admin_controller.dart';

class CreateOfficerController extends GetxController {
  CreateOfficerController(
    this._repository,
    this._authService,
    this._profileRepository,
    this._adminController,
  );

  final CreateOfficerRepository _repository;
  final AuthService _authService;
  final ProfileRepository _profileRepository;
  final AdminController _adminController;

  final isSubmitting = false.obs;
  final errorMessage = RxnString();
  final successMessage = RxnString();

  Future<bool> createOfficer({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (isSubmitting.value) return false;
    isSubmitting.value = true;
    errorMessage.value = null;
    successMessage.value = null;
    try {
      final userId = _authService.currentUser?.id;
      if (userId == null || _authService.currentSession == null) {
        throw const CreateOfficerException(
          CreateOfficerFailureType.unauthorized,
          'Your session has expired. Sign in again.',
        );
      }

      // This client-side check improves feedback. The Edge Function performs
      // the authoritative role check using the verified access token.
      final caller = await _profileRepository.fetchForUser(userId);
      if (caller.role != UserRole.admin) {
        throw const CreateOfficerException(
          CreateOfficerFailureType.forbidden,
          'Only administrators can create officer accounts.',
        );
      }

      final officer = await _repository.createOfficer(
        fullName: fullName,
        email: email,
        password: password,
      );
      await _adminController.loadDashboard(showLoading: false);
      successMessage.value = 'Officer ${officer.fullName} created successfully.';
      return true;
    } on CreateOfficerException catch (error) {
      errorMessage.value = error.message;
      return false;
    } catch (_) {
      errorMessage.value =
          'The officer could not be created. Check your connection and try again.';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }
}
