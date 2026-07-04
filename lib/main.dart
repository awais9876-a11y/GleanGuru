import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/auth/firebase_auth_service.dart';
import 'features/auth/auth_bloc.dart';
import 'main_entry/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is optional at build time: if this app hasn't been connected to
  // a Firebase project yet (no firebase_options.dart / web config in
  // web/index.html), initialization would throw at runtime. We guard it so
  // the app still boots (email/social sign-in will simply be unavailable
  // until Firebase is configured) instead of showing a blank/crashed page.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase failed to initialize: $e');
  }

  runApp(
    BlocProvider<AuthBloc>(
      create: (_) => AuthBloc(authService: FirebaseAuthService()),
      child: App(),
    ),
  );
}
