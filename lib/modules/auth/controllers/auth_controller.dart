import 'dart:async';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/auth_service.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/profile_repository.dart';

enum AuthStatus { loading, signedOut, signedIn, error }

class AuthController extends GetxController {
  AuthController({
    required AuthService authService,
    required ProfileRepository profileRepository,
  }) : _authService = authService,
       _profileRepository = profileRepository;

  final AuthService _authService;
  final ProfileRepository _profileRepository;
  final status = AuthStatus.loading.obs;
  final profile = Rxn<UserProfile>();
  final errorMessage = RxnString();
  final isSubmitting = false.obs;
  StreamSubscription<AuthState>? _authSubscription;
  int _sessionRevision = 0;

  @override
  void onInit() {
    super.onInit();
    _authSubscription = _authService.authStateChanges.listen(
      (event) => _applySession(event.session),
      onError: (Object error) {
        errorMessage.value = 'Could not monitor the sign-in session.';
        status.value = AuthStatus.error;
      },
    );
    unawaited(_applySession(_authService.currentSession));
  }

  Future<void> signIn(String email, String password) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      await _authService.signInWithEmail(email: email, password: password);
      // The auth-state listener fetches the trusted profile and selects the
      // appropriate signed-in state.
    } on AuthException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Sign-in failed. Please try again.';
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> signOut() async {
    errorMessage.value = null;
    try {
      await _authService.signOut();
    } on AuthException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Could not sign out. Please try again.';
    }
  }

  Future<void> retrySession() => _applySession(_authService.currentSession);

  Future<void> _applySession(Session? session) async {
    final revision = ++_sessionRevision;
    errorMessage.value = null;
    if (session == null) {
      profile.value = null;
      status.value = AuthStatus.signedOut;
      return;
    }

    status.value = AuthStatus.loading;
    try {
      final userProfile = await _profileRepository.fetchForUser(session.user.id);
      if (revision != _sessionRevision) return;
      profile.value = userProfile;
      status.value = AuthStatus.signedIn;
    } catch (_) {
      if (revision != _sessionRevision) return;
      profile.value = null;
      errorMessage.value =
          'Your account is signed in, but its profile could not be loaded.';
      status.value = AuthStatus.error;
    }
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    super.onClose();
  }
}
