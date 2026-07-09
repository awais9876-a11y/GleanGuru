import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/auth/firebase_auth_service.dart';
import 'core/auth/no_op_auth_service.dart';
import 'features/auth/auth_bloc.dart';
import 'main_entry/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show a visible error on screen instead of a blank white page when
  // something goes wrong during a widget build. Flutter's default
  // ErrorWidget only shows details in debug mode; in release builds
  // (what Vercel serves) it renders nothing at all, which is exactly why
  // this was previously an unexplained white screen.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Something went wrong:\n${details.exceptionAsString()}',
            style: const TextStyle(color: Colors.redAccent, fontSize: 14),
          ),
        ),
      ),
    );
  };

  // Firebase is optional at runtime: if this app hasn't been connected to
  // a real Firebase project yet (no Firebase Web config added to
  // web/index.html), initializeApp() throws here - we catch that safely.
  //
  // Previously, FirebaseAuthService() was constructed unconditionally right
  // after this block, regardless of whether Firebase actually initialized.
  // Its constructor touches FirebaseAuth.instance, which throws
  // "[core/no-app] No Firebase App '[DEFAULT]' has been created" if
  // Firebase never initialized - and that throw happened during the first
  // widget build, uncaught, producing the blank white screen. We now only
  // construct FirebaseAuthService if Firebase actually came up; otherwise
  // we fall back to a no-op AuthService so the app still renders (sign-in
  // simply reports itself as unavailable until Firebase is configured -
  // see README).
  var firebaseAvailable = false;
  try {
    await Firebase.initializeApp();
    firebaseAvailable = true;
  } catch (e) {
    debugPrint('Firebase failed to initialize: $e');
  }

  final authService = firebaseAvailable ? FirebaseAuthService() : NoOpAuthService();
  final authBloc = AuthBloc(authService: authService);

  runApp(
    BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: App(authBloc: authBloc),
    ),
  );
}
