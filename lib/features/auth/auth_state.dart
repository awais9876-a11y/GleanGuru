part of 'auth_bloc.dart';

/// Base auth state
abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object?> get props => [];
}

/// Initial auth state
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading state during auth operations
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Authenticated state with user data
class AuthAuthenticated extends AuthState {
  final User user;
  
  const AuthAuthenticated(this.user);
  
  @override
  List<Object?> get props => [user];
}

/// Unauthenticated state
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Error state with error message
class AuthError extends AuthState {
  final String message;
  
  const AuthError(this.message);
  
  @override
  List<Object?> get props => [message];
}

/// Token refresh required state
class AuthTokenRefreshRequired extends AuthState {
  const AuthTokenRefreshRequired();
}
