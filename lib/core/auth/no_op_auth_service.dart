import '../../features/auth/auth_bloc.dart' show AuthService, User, BiometricResult;

/// Fallback [AuthService] used when Firebase has not been configured for
/// this app yet (no real Firebase Web project connected). Every method
/// either safely reports "not signed in" or throws a clear, descriptive
/// error - never a raw Firebase "no-app" exception - so the app can still
/// render and be used, with sign-in features surfaced as unavailable
/// instead of crashing the whole app at startup.
class NoOpAuthService implements AuthService {
  static const _unavailableMessage =
      'Sign-in is not available: this app has not been connected to a '
      'Firebase project yet. See README.md for setup instructions.';

  @override
  Stream<User?> get authStateChanges => Stream<User?>.value(null);

  @override
  Future<User?> getCurrentUser() async => null;

  @override
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    throw Exception(_unavailableMessage);
  }

  @override
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    throw Exception(_unavailableMessage);
  }

  @override
  Future<User?> signInWithGoogle() async {
    throw Exception(_unavailableMessage);
  }

  @override
  Future<User?> signInWithApple() async {
    throw Exception(_unavailableMessage);
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<BiometricResult> authenticateWithBiometrics() async {
    return BiometricResult(success: false, message: _unavailableMessage);
  }

  @override
  Future<void> resetPassword(String email) async {
    throw Exception(_unavailableMessage);
  }
}
