import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';

import 'package:multimodal_memory_agent/features/auth/auth_bloc.dart';

/// Hand-written fake AuthService, used instead of a mockito @GenerateMocks
/// codegen mock. A generated mock requires running `build_runner` before
/// every analyze/test run and committing (or regenerating) the resulting
/// auth_bloc_test.mocks.dart file - a step that's easy to forget and breaks
/// `flutter analyze`/`flutter test` the moment it's missing. This fake needs
/// no code generation step at all.
class FakeAuthService implements AuthService {
  User? nextUser;
  Object? errorToThrow;
  BiometricResult? nextBiometricResult;

  bool signOutCalled = false;
  String? lastSignInEmail;
  String? lastSignInPassword;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<User?> getCurrentUser() async => nextUser;

  @override
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    lastSignInEmail = email;
    lastSignInPassword = password;
    if (errorToThrow != null) throw errorToThrow!;
    return nextUser;
  }

  @override
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return nextUser;
  }

  @override
  Future<User?> signInWithGoogle() async {
    if (errorToThrow != null) throw errorToThrow!;
    return nextUser;
  }

  @override
  Future<User?> signInWithApple() async {
    if (errorToThrow != null) throw errorToThrow!;
    return nextUser;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<BiometricResult> authenticateWithBiometrics() async {
    return nextBiometricResult ??
        BiometricResult(success: false, message: 'Not configured in test');
  }

  @override
  Future<void> resetPassword(String email) async {}
}

void main() {
  late AuthBloc authBloc;
  late FakeAuthService fakeAuthService;

  setUp(() {
    fakeAuthService = FakeAuthService();
    authBloc = AuthBloc(authService: fakeAuthService);
  });

  tearDown(() {
    authBloc.close();
  });

  group('AuthBloc', () {
    final testUser = User(
      id: 'test-123',
      email: 'test@example.com',
      name: 'Test User',
      createdAt: DateTime.now(),
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when EmailSignInRequested succeeds',
      build: () {
        fakeAuthService.nextUser = testUser;
        return authBloc;
      },
      act: (bloc) => bloc.add(const EmailSignInRequested(
        email: 'test@example.com',
        password: 'password123',
      )),
      expect: () => [
        const AuthLoading(),
        AuthAuthenticated(testUser),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when EmailSignInRequested fails',
      build: () {
        fakeAuthService.errorToThrow = Exception('Invalid credentials');
        return authBloc;
      },
      act: (bloc) => bloc.add(const EmailSignInRequested(
        email: 'test@example.com',
        password: 'wrongpassword',
      )),
      expect: () => [
        const AuthLoading(),
        isA<AuthError>(),
      ],
      verify: (_) {
        expect(fakeAuthService.lastSignInEmail, 'test@example.com');
        expect(fakeAuthService.lastSignInPassword, 'wrongpassword');
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when GoogleSignInRequested succeeds',
      build: () {
        fakeAuthService.nextUser = testUser;
        return authBloc;
      },
      act: (bloc) => bloc.add(const GoogleSignInRequested()),
      expect: () => [
        const AuthLoading(),
        AuthAuthenticated(testUser),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when GoogleSignInRequested is cancelled',
      build: () {
        fakeAuthService.nextUser = null;
        return authBloc;
      },
      act: (bloc) => bloc.add(const GoogleSignInRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when SignUpRequested succeeds',
      build: () {
        fakeAuthService.nextUser = testUser;
        return authBloc;
      },
      act: (bloc) => bloc.add(const SignUpRequested(
        email: 'newuser@example.com',
        password: 'securepass123',
        name: 'New User',
      )),
      expect: () => [
        const AuthLoading(),
        AuthAuthenticated(testUser),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when SignOutRequested succeeds',
      build: () => authBloc,
      act: (bloc) => bloc.add(const SignOutRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        expect(fakeAuthService.signOutCalled, isTrue);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when BiometricAuthRequested succeeds',
      build: () {
        fakeAuthService.nextBiometricResult =
            BiometricResult(success: true, message: 'Success');
        fakeAuthService.nextUser = testUser;
        return authBloc;
      },
      act: (bloc) => bloc.add(const BiometricAuthRequested()),
      expect: () => [
        const AuthLoading(),
        AuthAuthenticated(testUser),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when BiometricAuthRequested fails',
      build: () {
        fakeAuthService.nextBiometricResult =
            BiometricResult(success: false, message: 'Failed');
        return authBloc;
      },
      act: (bloc) => bloc.add(const BiometricAuthRequested()),
      expect: () => [
        const AuthLoading(),
        isA<AuthError>(),
      ],
    );
  });
}
