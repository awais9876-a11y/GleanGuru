import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../features/auth/auth_bloc.dart' show AuthService, User, BiometricResult;
import '../security/biometric_service.dart';

/// Concrete [AuthService] implementation backed by Firebase Authentication,
/// with Google / Apple federated sign-in and local biometric unlock.
class FirebaseAuthService implements AuthService {
  final fb.FirebaseAuth _firebaseAuth;
  final GoogleSignIn? _providedGoogleSignIn;
  final BiometricService _biometricService;

  GoogleSignIn? _googleSignIn;

  FirebaseAuthService({
    fb.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    BiometricService? biometricService,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _providedGoogleSignIn = googleSignIn,
        _biometricService = biometricService ?? BiometricService();

  /// GoogleSignIn is constructed lazily, the first time it's actually
  /// needed (i.e. when a user taps "Sign in with Google"), not eagerly at
  /// app startup. On web, constructing it triggers loading Google
  /// Identity Services' script (accounts.google.com/gsi/client) - doing
  /// that unconditionally during app boot meant any CSP restriction or
  /// network hiccup with that specific script could break the entire
  /// app's startup, not just the Google sign-in button.
  GoogleSignIn get _googleSignInInstance =>
      _googleSignIn ??= _providedGoogleSignIn ?? GoogleSignIn();

  User? _mapUser(fb.User? user) {
    if (user == null) return null;
    return User(
      id: user.uid,
      email: user.email ?? '',
      name: user.displayName,
      avatarUrl: user.photoURL,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
    );
  }

  @override
  Stream<User?> get authStateChanges =>
      _firebaseAuth.authStateChanges().map(_mapUser);

  @override
  Future<User?> getCurrentUser() async => _mapUser(_firebaseAuth.currentUser);

  @override
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _mapUser(credential.user);
  }

  @override
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (name != null && name.isNotEmpty) {
      await credential.user?.updateDisplayName(name);
      await credential.user?.reload();
    }
    return _mapUser(_firebaseAuth.currentUser);
  }

  @override
  Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignInInstance.signIn();
    if (googleUser == null) {
      // User cancelled the sign-in flow.
      return null;
    }

    final googleAuth = await googleUser.authentication;
    final credential = fb.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    return _mapUser(userCredential.user);
  }

  @override
  Future<User?> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = fb.OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(oauthCredential);
    return _mapUser(userCredential.user);
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      if (_googleSignIn != null) _googleSignIn!.signOut(),
    ]);
  }

  @override
  Future<BiometricResult> authenticateWithBiometrics() async {
    final result = await _biometricService.authenticate(
      reason: 'Authenticate to access Memory Agent',
    );
    return BiometricResult(success: result.success, message: result.message);
  }

  @override
  Future<void> resetPassword(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }
}
