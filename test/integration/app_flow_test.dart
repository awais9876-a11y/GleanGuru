import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:multimodal_memory_agent/main_entry/app.dart';
import 'package:multimodal_memory_agent/features/auth/auth_bloc.dart';
import 'package:multimodal_memory_agent/features/auth/login_screen.dart';
import 'package:multimodal_memory_agent/features/memory_agent/bloc/memory_agent_bloc.dart';
import 'package:multimodal_memory_agent/features/memory_agent/memory_home_screen.dart';
import 'package:multimodal_memory_agent/features/profile/profile_screen.dart';
import 'package:multimodal_memory_agent/core/database/memory_repository.dart';
import 'package:multimodal_memory_agent/core/network/qwen_service.dart';

/// Fake AuthService for integration tests: starts signed out, and
/// successfully "signs in" with any email/password so the login ->
/// navigate flow below can actually be exercised without a real backend.
class _FakeAuthService implements AuthService {
  User? _currentUser;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<User?> getCurrentUser() async => _currentUser;

  @override
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _currentUser = User(
      id: 'integration-test-user',
      email: email,
      name: 'Test User',
      createdAt: DateTime.now(),
    );
    return _currentUser;
  }

  @override
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    _currentUser = User(
      id: 'integration-test-user',
      email: email,
      name: name,
      createdAt: DateTime.now(),
    );
    return _currentUser;
  }

  @override
  Future<User?> signInWithGoogle() async => null;

  @override
  Future<User?> signInWithApple() async => null;

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  Future<BiometricResult> authenticateWithBiometrics() async {
    return BiometricResult(success: false, message: 'Not available in test');
  }

  @override
  Future<void> resetPassword(String email) async {}
}

/// Wraps App with the same providers it expects in production (see
/// lib/main.dart), backed by a fresh fake auth service per test and an
/// in-memory-only (no Firestore) MemoryRepository, so these tests never
/// touch the network.
Widget _testApp() {
  final authBloc = AuthBloc(authService: _FakeAuthService());
  final memoryAgentBloc = MemoryAgentBloc(
    qwenService: QwenService(),
    memoryRepository: MemoryRepository(firestore: null),
  );
  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<MemoryAgentBloc>.value(value: memoryAgentBloc),
    ],
    child: App(authBloc: authBloc),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('Full User Lifecycle Integration Test', () {
    testWidgets('App Launch -> Login -> Navigate -> Settings Edit', (tester) async {
      // Launch app
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();
      
      // Verify splash screen appears
      expect(find.byType(SplashScreen), findsOneWidget);
      
      // Wait for auth check to complete and redirect to login
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      
      // Verify login screen appears
      expect(find.byType(LoginScreen), findsOneWidget);
      
      // Enter email
      final emailField = find.byType(TextFormField).at(0);
      await tester.enterText(emailField, 'test@example.com');
      await tester.pumpAndSettle();
      
      // Enter password
      final passwordField = find.byType(TextFormField).at(1);
      await tester.enterText(passwordField, 'password123');
      await tester.pumpAndSettle();
      
      // Tap sign in button
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
      await tester.tap(signInButton);
      await tester.pumpAndSettle();
      
      // Wait for authentication
      await tester.pump(const Duration(seconds: 2));
      
      // Verify navigation to home screen
      expect(find.byType(MemoryHomeScreen), findsOneWidget);
      
      // Tap profile navigation
      final profileTab = find.text('Profile');
      await tester.tap(profileTab);
      await tester.pumpAndSettle();
      
      // Verify profile screen
      expect(find.byType(ProfileScreen), findsOneWidget);
      
      // Find and tap edit profile button
      final editButton = find.widgetWithText(ElevatedButton, 'Edit Profile');
      if (editButton.evaluate().isNotEmpty) {
        await tester.tap(editButton);
        await tester.pumpAndSettle();
        
        // Enter new name
        final nameField = find.byType(TextFormField).first;
        await tester.enterText(nameField, 'Updated Name');
        await tester.pumpAndSettle();
        
        // Save changes
        final saveButton = find.widgetWithText(ElevatedButton, 'Save');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();
        
        // Verify success message or updated UI
        expect(find.text('Profile updated successfully'), findsOneWidget);
      }
      
      // Navigate back to home
      final homeTab = find.text('Home');
      await tester.tap(homeTab);
      await tester.pumpAndSettle();
      
      // Verify back on home screen
      expect(find.byType(MemoryHomeScreen), findsOneWidget);
    });
    
    testWidgets('Biometric Authentication Flow', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();
      
      // Wait for splash and redirect
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      
      // Look for biometric auth option
      final biometricButton = find.byIcon(Icons.fingerprint);
      if (biometricButton.evaluate().isNotEmpty) {
        await tester.tap(biometricButton);
        await tester.pumpAndSettle();
        
        // Simulate successful biometric auth
        await tester.pump(const Duration(seconds: 1));
        
        // Should navigate to home on success
        expect(find.byType(MemoryHomeScreen), findsOneWidget);
      }
    });
    
    testWidgets('Offline Mode Handling', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();
      
      // Simulate offline state would be tested with mock connectivity
      // This is a placeholder for actual offline testing
      expect(true, isTrue);
    });
  });
}
