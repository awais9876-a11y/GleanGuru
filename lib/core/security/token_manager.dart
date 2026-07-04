import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

/// Secure Token Manager for JWT storage and automatic refresh
/// Uses platform-specific secure storage (Keychain/Keystore)
class TokenManager {
  final FlutterSecureStorage _storage;
  final String _accessTokenKey = 'access_token';
  final String _refreshTokenKey = 'refresh_token';
  final String _tokenExpiryKey = 'token_expiry';
  
  TokenManager({required FlutterSecureStorage storage})
      : _storage = storage;
  
  /// Store authentication tokens securely
  Future<void> storeTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiry,
  }) async {
    try {
      await _storage.write(
        key: _accessTokenKey,
        value: accessToken,
        iOptions: const IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );
      
      await _storage.write(
        key: _refreshTokenKey,
        value: refreshToken,
        iOptions: const IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );
      
      await _storage.write(
        key: _tokenExpiryKey,
        value: expiry.toIso8601String(),
      );
    } catch (e) {
      throw TokenStorageException('Failed to store tokens: $e');
    }
  }
  
  /// Retrieve access token
  Future<String?> getAccessToken() async {
    return await _storage.read(
      key: _accessTokenKey,
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
      aOptions: const AndroidOptions(
        encryptedSharedPreferences: true,
      ),
    );
  }
  
  /// Retrieve refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(
      key: _refreshTokenKey,
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
      aOptions: const AndroidOptions(
        encryptedSharedPreferences: true,
      ),
    );
  }
  
  /// Check if token is expired
  Future<bool> isTokenExpired() async {
    final expiryString = await _storage.read(key: _tokenExpiryKey);
    if (expiryString == null) return true;
    
    final expiry = DateTime.parse(expiryString);
    return DateTime.now().isAfter(expiry);
  }
  
  /// Check if token needs refresh (within 5 minutes of expiry)
  Future<bool> needsRefresh() async {
    final expiryString = await _storage.read(key: _tokenExpiryKey);
    if (expiryString == null) return true;
    
    final expiry = DateTime.parse(expiryString);
    final now = DateTime.now();
    final threshold = now.add(const Duration(minutes: 5));
    
    return threshold.isAfter(expiry);
  }
  
  /// Decode JWT to extract claims
  Map<String, dynamic>? decodeToken(String? token) {
    if (token == null || token.isEmpty) return null;
    
    try {
      return JwtDecoder.decode(token);
    } catch (e) {
      return null;
    }
  }
  
  /// Get user ID from token claims
  Future<String?> getUserIdFromToken() async {
    final token = await getAccessToken();
    final claims = decodeToken(token);
    return claims?['sub'] as String?;
  }
  
  /// Clear all stored tokens (logout)
  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _tokenExpiryKey);
  }
  
  /// Check if user has valid session
  Future<bool> hasValidSession() async {
    final token = await getAccessToken();
    if (token == null) return false;
    
    final expired = await isTokenExpired();
    return !expired;
  }
}

class TokenStorageException implements Exception {
  final String message;
  TokenStorageException(this.message);
  
  @override
  String toString() => 'TokenStorageException: $message';
}
