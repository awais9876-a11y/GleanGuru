part of 'auth_bloc.dart';

/// Base auth event
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  
  @override
  List<Object?> get props => [];
}

/// Check authentication status on app launch
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// Sign in with email and password
class EmailSignInRequested extends AuthEvent {
  final String email;
  final String password;
  
  const EmailSignInRequested({
    required this.email,
    required this.password,
  });
  
  @override
  List<Object?> get props => [email, password];
}

/// Sign in with Google OAuth
class GoogleSignInRequested extends AuthEvent {
  const GoogleSignInRequested();
}

/// Sign in with Apple ID
class AppleSignInRequested extends AuthEvent {
  const AppleSignInRequested();
}

/// Sign up with email and password
class SignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String? name;
  
  const SignUpRequested({
    required this.email,
    required this.password,
    this.name,
  });
  
  @override
  List<Object?> get props => [email, password, name];
}

/// Sign out current user
class SignOutRequested extends AuthEvent {
  const SignOutRequested();
}

/// Authenticate with biometrics
class BiometricAuthRequested extends AuthEvent {
  const BiometricAuthRequested();
}

/// Reset password request
class PasswordResetRequested extends AuthEvent {
  final String email;
  
  const PasswordResetRequested({required this.email});
  
  @override
  List<Object?> get props => [email];
}

/// Internal event: fired whenever AuthService's authStateChanges stream
/// emits, so the resulting state transition goes through the BLoC's normal
/// event-handler flow instead of calling emit() directly from a stream
/// listener (which bloc disallows outside of an event handler).
class _AuthUserChanged extends AuthEvent {
  final User? user;

  const _AuthUserChanged(this.user);

  @override
  List<Object?> get props => [user];
}
