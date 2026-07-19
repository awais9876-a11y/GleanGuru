import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/database/memory_repository.dart';
import 'core/network/qwen_service.dart';
import 'features/memory_agent/bloc/memory_agent_bloc.dart';
import 'main_entry/app.dart';

void main() {
  // runZonedGuarded catches uncaught errors that happen *outside* Flutter's
  // widget-build phase (e.g. stray async callbacks) - these are invisible
  // to both try/catch in main() and to ErrorWidget.builder below, and could
  // otherwise silently kill the whole app's rendering (a white screen with
  // no on-screen indication of what happened at all).
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    // Show a visible error on screen instead of a blank white page when
    // something goes wrong during a widget build. Flutter's default
    // ErrorWidget only shows details in debug mode; in release builds
    // (what Vercel/Alibaba serve) it renders nothing at all, which would
    // otherwise be an unexplained white screen.
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

    final memoryAgentBloc = MemoryAgentBloc(
      qwenService: QwenService(),
      memoryRepository: MemoryRepository(),
    );

    runApp(
      BlocProvider<MemoryAgentBloc>.value(
        value: memoryAgentBloc,
        child: const App(),
      ),
    );
  }, (error, stack) {
    // Last-resort catch: log clearly instead of a silent white screen.
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}
