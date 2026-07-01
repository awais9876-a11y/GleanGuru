import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:multimodal_memory_agent/features/auth/auth_bloc.dart';

@GenerateMocks([AuthService])
import 'auth_bloc_test.mocks.dart';

void main() {
  late AuthBloc authBloc;
  late MockAuthService mockAuthService;
  
  setUp(() {
    mockAuthService = MockAuthService();
    authBloc = AuthBloc(authService: mockAuthService);
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
        when(mockAuthService.signInWithEmail(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async => testUser);
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
        when(mockAuthService.signInWithEmail(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenThrow(Exception('Invalid credentials'));
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
        verify(mockAuthService.signInWithEmail(
          email: 'test@example.com',
          password: 'wrongpassword',
        )).called(1);
      },
    );
    
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when GoogleSignInRequested succeeds',
      build: () {
        when(mockAuthService.signInWithGoogle()).thenAnswer((_) async => testUser);
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
        when(mockAuthService.signInWithGoogle()).thenAnswer((_) async => null);
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
        when(mockAuthService.signUpWithEmail(
          email: anyNamed('email'),
          password: anyNamed('password'),
          name: anyNamed('name'),
        )).thenAnswer((_) async => testUser);
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
      build: () {
        when(mockAuthService.signOut()).thenAnswer((_) async => {});
        return authBloc;
      },
      act: (bloc) => bloc.add(const SignOutRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        verify(mockAuthService.signOut()).called(1);
      },
    );
    
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when BiometricAuthRequested succeeds',
      build: () {
        when(mockAuthService.authenticateWithBiometrics())
            .thenAnswer((_) async => BiometricResult(success: true, message: 'Success'));
        when(mockAuthService.getCurrentUser()).thenAnswer((_) async => testUser);
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
        when(mockAuthService.authenticateWithBiometrics())
            .thenAnswer((_) async => BiometricResult(success: false, message: 'Failed'));
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
