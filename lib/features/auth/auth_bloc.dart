import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Authentication BLoC for managing auth state transitions
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  StreamSubscription? _authStateSubscription;
  
  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<EmailSignInRequested>(_onEmailSignInRequested);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<AppleSignInRequested>(_onAppleSignInRequested);
    on<SignUpRequested>(_onSignUpRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<BiometricAuthRequested>(_onBiometricAuthRequested);
    
    // Listen to auth state changes
    _authStateSubscription = _authService.authStateChanges.listen((user) {
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    });
  }
  
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError('Failed to check auth status: $e'));
    }
  }
  
  Future<void> _onEmailSignInRequested(
    EmailSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      final user = await _authService.signInWithEmail(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError('Sign in failed: $e'));
    }
  }
  
  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError('Google sign in failed: $e'));
    }
  }
  
  Future<void> _onAppleSignInRequested(
    AppleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      final user = await _authService.signInWithApple();
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError('Apple sign in failed: $e'));
    }
  }
  
  Future<void> _onSignUpRequested(
    SignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      final user = await _authService.signUpWithEmail(
        email: event.email,
        password: event.password,
        name: event.name,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError('Sign up failed: $e'));
    }
  }
  
  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      await _authService.signOut();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError('Sign out failed: $e'));
    }
  }
  
  Future<void> _onBiometricAuthRequested(
    BiometricAuthRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      final result = await _authService.authenticateWithBiometrics();
      if (result.success) {
        final user = await _authService.getCurrentUser();
        if (user != null) {
          emit(AuthAuthenticated(user));
        } else {
          emit(AuthUnauthenticated());
        }
      } else {
        emit(AuthError('Biometric authentication failed: ${result.message}'));
      }
    } catch (e) {
      emit(AuthError('Biometric auth failed: $e'));
    }
  }
  
  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}

/// Auth Service interface
abstract class AuthService {
  Stream<User?> get authStateChanges;
  Future<User?> getCurrentUser();
  Future<User?> signInWithEmail({required String email, required String password});
  Future<User?> signUpWithEmail({required String email, required String password, String? name});
  Future<User?> signInWithGoogle();
  Future<User?> signInWithApple();
  Future<void> signOut();
  Future<BiometricResult> authenticateWithBiometrics();
  Future<void> resetPassword(String email);
}

/// User model
class User extends Equatable {
  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;
  final DateTime createdAt;
  
  const User({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    required this.createdAt,
  });
  
  @override
  List<Object?> get props => [id, email, name, avatarUrl, createdAt];
}

/// Biometric result wrapper
class BiometricResult {
  final bool success;
  final String message;
  
  BiometricResult({required this.success, required this.message});
}
