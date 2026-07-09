import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_bloc.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/memory_agent/memory_home_screen.dart';
import '../features/profile/profile_screen.dart';
import 'theme_config.dart';

/// Bridges a Stream (here, AuthBloc's state stream) into a Listenable that
/// GoRouter can use as `refreshListenable`, so the router's `redirect`
/// callback is automatically re-evaluated every time auth state changes -
/// not just when something explicitly triggers navigation.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Main Application Widget
/// Configures navigation, theming, and dependency injection
class App extends StatelessWidget {
  final AuthBloc authBloc;
  final GoRouter _router;
  
  App({super.key, required this.authBloc}) : _router = _createRouter(authBloc);
  
  static GoRouter _createRouter(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      routes: [
        GoRoute(
          path: '/splash',
          name: 'splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          name: 'signup',
          builder: (context, state) => const SignUpScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              pageBuilder: (context, state) => NoTransitionPage(child: MemoryHomeScreen()),
            ),
            GoRoute(
              path: '/profile',
              name: 'profile',
              pageBuilder: (context, state) => NoTransitionPage(child: ProfileScreen()),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => ErrorScreen(error: state.error),
      redirect: (context, state) {
        final authState = context.read<AuthBloc>().state;
        final isAuthenticated = authState is AuthAuthenticated;
        final isCheckingAuth = authState is AuthInitial || authState is AuthLoading;
        final isLoggingIn = state.matchedLocation == '/login' || 
                           state.matchedLocation == '/signup';
        final isSplash = state.matchedLocation == '/splash';
        
        // Still resolving the initial auth check: stay on splash, don't
        // redirect anywhere yet.
        if (isCheckingAuth) {
          return isSplash ? null : '/splash';
        }
        
        // Auth check has resolved: leave splash for the correct destination.
        if (isSplash) {
          return isAuthenticated ? '/home' : '/login';
        }
        
        if (!isAuthenticated && !isLoggingIn) {
          return '/login';
        }
        
        if (isAuthenticated && isLoggingIn) {
          return '/home';
        }
        
        return null;
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Memory Agent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}

/// Main application shell with bottom navigation
class MainShell extends StatefulWidget {
  final Widget child;
  
  const MainShell({super.key, required this.child});
  
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 0) {
            context.go('/home');
          } else if (index == 1) {
            context.go('/profile');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Splash screen for app initialization
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    // Initialize all services
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      context.read<AuthBloc>().add(const AuthCheckRequested());
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology, size: 80),
            const SizedBox(height: 24),
            const Text(
              'Memory Agent',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Error screen for route errors
class ErrorScreen extends StatelessWidget {
  final Exception? error;
  
  const ErrorScreen({super.key, this.error});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'An error occurred: ${error?.toString() ?? 'Unknown error'}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
