import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

/// Biometric Authentication Service for FaceID/TouchID/Fingerprint
/// Provides hardware-level biometric validation with fallback options
class BiometricService {
  final LocalAuthentication _localAuth;
  
  BiometricService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();
  
  /// Check if biometric authentication is available on device
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      return canCheckBiometrics && isDeviceSupported;
    } on PlatformException catch (e) {
      throw BiometricException('Biometric availability check failed: ${e.message}');
    }
  }
  
  /// Get list of enrolled biometric types
  Future<List<BiometricType>> getEnrolledBiometrics() async {
    try {
      return await _localAuth.getEnrolledBiometrics();
    } on PlatformException catch (e) {
      throw BiometricException('Failed to get enrolled biometrics: ${e.message}');
    }
  }
  
  /// Authenticate user with biometrics
  Future<BiometricResult> authenticate({
    String reason = 'Please authenticate to continue',
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final available = await isBiometricAvailable();
      if (!available) {
        return BiometricResult(
          success: false,
          error: BiometricError.notAvailable,
          message: 'Biometric authentication is not available on this device',
        );
      }
      
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      if (authenticated) {
        return BiometricResult(
          success: true,
          error: null,
          message: 'Authentication successful',
        );
      } else {
        return BiometricResult(
          success: false,
          error: BiometricError.userCancelled,
          message: 'User cancelled authentication',
        );
      }
    } on PlatformException catch (e) {
      return BiometricResult(
        success: false,
        error: _mapPlatformError(e.code),
        message: e.message ?? 'An unknown error occurred',
      );
    } on Exception catch (e) {
      return BiometricResult(
        success: false,
        error: BiometricError.unknown,
        message: e.toString(),
      );
    }
  }
  
  /// Authenticate with fallback to device credentials
  Future<BiometricResult> authenticateWithFallback({
    String reason = 'Please authenticate to continue',
  }) async {
    try {
      final available = await isBiometricAvailable();
      if (!available) {
        return BiometricResult(
          success: false,
          error: BiometricError.notAvailable,
          message: 'Biometric authentication is not available',
        );
      }
      
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      
      if (authenticated) {
        return BiometricResult(
          success: true,
          error: null,
          message: 'Authentication successful',
        );
      } else {
        return BiometricResult(
          success: false,
          error: BiometricError.userCancelled,
          message: 'User cancelled authentication',
        );
      }
    } on PlatformException catch (e) {
      return BiometricResult(
        success: false,
        error: _mapPlatformError(e.code),
        message: e.message ?? 'An unknown error occurred',
      );
    }
  }
  
  /// Cancel any ongoing biometric authentication
  Future<void> cancelAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } on PlatformException catch (e) {
      throw BiometricException('Failed to cancel authentication: ${e.message}');
    }
  }
  
  /// Map platform-specific error codes to BiometricError enum
  BiometricError _mapPlatformError(String code) {
    switch (code) {
      case 'lockedOut':
        return BiometricError.lockedOut;
      case 'userCancel':
        return BiometricError.userCancelled;
      case 'systemCancel':
        return BiometricError.systemCancelled;
      case 'passcodeNotSet':
        return BiometricError.noPasscode;
      case 'notAvailable':
        return BiometricError.notAvailable;
      case 'notEnrolled':
        return BiometricError.notEnrolled;
      default:
        return BiometricError.unknown;
    }
  }
}

/// Result of biometric authentication attempt
class BiometricResult {
  final bool success;
  final BiometricError? error;
  final String message;
  
  BiometricResult({
    required this.success,
    this.error,
    required this.message,
  });
}

/// Biometric error types
enum BiometricError {
  notAvailable,
  notEnrolled,
  lockedOut,
  userCancelled,
  systemCancelled,
  noPasscode,
  unknown,
}

/// Custom exception for biometric operations
class BiometricException implements Exception {
  final String message;
  BiometricException(this.message);
  
  @override
  String toString() => 'BiometricException: $message';
}
