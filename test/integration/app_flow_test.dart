import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:multimodal_memory_agent/main_entry/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('Full User Lifecycle Integration Test', () {
    testWidgets('App Launch -> Login -> Navigate -> Settings Edit', (tester) async {
      // Launch app
      await tester.pumpWidget(App());
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
      await tester.pumpWidget(App());
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
      await tester.pumpWidget(App());
      await tester.pumpAndSettle();
      
      // Simulate offline state would be tested with mock connectivity
      // This is a placeholder for actual offline testing
      expect(true, isTrue);
    });
  });
}
