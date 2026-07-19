import 'package:flutter/material.dart';

import '../features/memory_agent/memory_home_screen.dart';
import 'theme_config.dart';

/// Root application widget. Deliberately a single screen for now (no
/// routing, no auth) - the whole app is the Memory Agent chat/knowledge
/// bank. See README.md for why Firebase auth + Firestore were removed and
/// how to bring multi-device sync back later if you need it.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Agent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MemoryHomeScreen(),
    );
  }
}
