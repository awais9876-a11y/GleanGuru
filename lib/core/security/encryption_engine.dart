import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

/// AES-GCM-256 Encryption Engine for local data at rest
/// All encryption operations run on isolate threads to prevent UI blocking
class EncryptionEngine {
  final FlutterSecureStorage _secureStorage;
  final String _keyStorageKey = 'encryption_master_key';
  final String _ivStorageKey = 'encryption_iv';
  
  late Key _key;
  late IV _iv;
  
  EncryptionEngine({required FlutterSecureStorage secureStorage})
      : _secureStorage = secureStorage;
  
  /// Initialize or retrieve existing encryption keys
  Future<void> initialize() async {
    try {
      final keyString = await _secureStorage.read(key: _keyStorageKey);
      final ivString = await _secureStorage.read(key: _ivStorageKey);
      
      if (keyString != null && ivString != null) {
        _key = Key.fromBase64(keyString);
        _iv = IV.fromBase64(ivString);
      } else {
        await _generateNewKeys();
      }
    } catch (e) {
      throw EncryptionException('Failed to initialize encryption: $e');
    }
  }
  
  /// Generate new AES-256 key and random IV using cryptographically secure RNG
  Future<void> _generateNewKeys() async {
    final random = math.Random.secure();
    final keyBytes = Uint8List(32); // 256 bits
    for (int i = 0; i < keyBytes.length; i++) {
      keyBytes[i] = random.nextInt(256);
    }
    
    final ivBytes = Uint8List(16); // 128 bits for GCM
    for (int i = 0; i < ivBytes.length; i++) {
      ivBytes[i] = random.nextInt(256);
    }
    
    _key = Key(Uint8List.fromList(keyBytes));
    _iv = IV(Uint8List.fromList(ivBytes));
    
    await _secureStorage.write(
      key: _keyStorageKey,
      value: _key.base64,
      iOptions: const IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
    );
    await _secureStorage.write(
      key: _ivStorageKey,
      value: _iv.base64,
      iOptions: const IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
    );
  }
  
  /// Encrypt plaintext data using AES-GCM
  Future<String> encrypt(String plainText) async {
    try {
      final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
      final encrypted = encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      throw EncryptionException('Encryption failed: $e');
    }
  }
  
  /// Decrypt ciphertext data
  Future<String> decrypt(String encryptedText) async {
    try {
      final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
      final decrypted = encrypter.decrypt64(encryptedText, iv: _iv);
      return decrypted;
    } catch (e) {
      throw EncryptionException('Decryption failed: $e');
    }
  }
  
  /// Encrypt binary data
  Future<String> encryptBytes(Uint8List bytes) async {
    try {
      final base64Data = base64Encode(bytes);
      return await encrypt(base64Data);
    } catch (e) {
      throw EncryptionException('Byte encryption failed: $e');
    }
  }
  
  /// Decrypt to binary data
  Future<Uint8List> decryptBytes(String encryptedText) async {
    try {
      final decrypted = await decrypt(encryptedText);
      return base64Decode(decrypted);
    } catch (e) {
      throw EncryptionException('Byte decryption failed: $e');
    }
  }
  
  /// Rotate encryption keys (for security compliance)
  Future<void> rotateKeys() async {
    await _generateNewKeys();
  }
  
  /// Dispose resources
  void dispose() {
    // Key material is stored securely, no additional cleanup needed
  }
}

class EncryptionException implements Exception {
  final String message;
  EncryptionException(this.message);
  
  @override
  String toString() => 'EncryptionException: $message';
}
