import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'core/auth/firebase_auth_service.dart';
import 'core/auth/no_op_auth_service.dart';
import 'core/database/memory_repository.dart';
import 'core/network/qwen_service.dart';
import 'features/auth/auth_bloc.dart';
import 'features/memory_agent/bloc/memory_agent_bloc.dart';
import 'main_entry/app.dart';

void main() {
  // runZonedGuarded catches uncaught errors that happen *outside* Flutter's
  // widget-build phase (e.g. in plugin registration, stray async
  // callbacks) - these are invisible to both try/catch in main() and to
  // ErrorWidget.builder below, and were previously able to silently kill
  // the whole app's rendering (a white screen with no on-screen indication
  // of what happened at all).
  runZonedGuarded(() async {
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

    // Also route Flutter framework errors (thrown during build/layout/paint)
    // through the same reporting path, and don't let them silently vanish.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };

    // Firebase is optional at runtime: if this app hasn't been connected to
    // a real Firebase project yet, initializeApp() throws here - we catch
    // that safely.
    //
    // Previously, FirebaseAuthService() was constructed unconditionally
    // right after this block, regardless of whether Firebase actually
    // initialized. Its constructor touches FirebaseAuth.instance, which
    // throws "[core/no-app] No Firebase App '[DEFAULT]' has been created"
    // if Firebase never initialized - and that throw happened during the
    // first widget build, uncaught, producing the blank white screen. We
    // now only construct FirebaseAuthService if Firebase actually came up;
    // otherwise we fall back to a no-op AuthService so the app still
    // renders (sign-in reports itself as unavailable instead).
    var firebaseAvailable = false;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      firebaseAvailable = true;
    } catch (e) {
      debugPrint('Firebase failed to initialize: $e');
    }

    final authService = firebaseAvailable ? FirebaseAuthService() : NoOpAuthService();
    final authBloc = AuthBloc(authService: authService);

    // Only construct a real Firestore-backed MemoryRepository if Firebase
    // actually initialized - same reasoning as authService above.
    // MemoryRepository itself also fails soft on every individual
    // operation, so this is a belt-and-suspenders guard against ever
    // touching FirebaseFirestore.instance without an app registered.
    final memoryRepository = MemoryRepository(
      firestore: firebaseAvailable ? FirebaseFirestore.instance : null,
    );
    final memoryAgentBloc = MemoryAgentBloc(
      qwenService: QwenService(),
      memoryRepository: memoryRepository,
    );

    runApp(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<MemoryAgentBloc>.value(value: memoryAgentBloc),
        ],
        child: App(authBloc: authBloc),
      ),
    );
  }, (error, stack) {
    // Last-resort catch: log clearly instead of a silent white screen.
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}
