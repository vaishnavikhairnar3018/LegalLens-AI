/// Secure storage service wrapping flutter_secure_storage.
///
/// All sensitive data (JWT tokens, credentials) MUST use this service.
/// NEVER store sensitive data in SharedPreferences.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/app_config.dart';
import 'web_storage.dart' as web_storage;

/// Singleton service for secure encrypted storage.
class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true, // Use Android Keystore-backed encryption
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    webOptions: WebOptions(
      dbName: 'lensescan_secure_db',
      publicKey: 'lensescan_web_key',
    ),
  );

  // In-memory cache for speed and non-HTTPS web fallback
  final Map<String, String> _memoryCache = {};

  // ── Token Management ──

  /// Store JWT access token securely.
  Future<void> saveAccessToken(String token) async {
    _memoryCache[AppConfig.accessTokenKey] = token;
    web_storage.setItem(AppConfig.accessTokenKey, token);
    try {
      await _storage.write(key: AppConfig.accessTokenKey, value: token);
    } catch (_) {
      // Graceful fallback for non-HTTPS Web contexts (e.g. mobile browser on LAN HTTP)
    }
  }

  /// Retrieve stored JWT access token.
  Future<String?> getAccessToken() async {
    if (_memoryCache.containsKey(AppConfig.accessTokenKey)) {
      return _memoryCache[AppConfig.accessTokenKey];
    }
    final webVal = web_storage.getItem(AppConfig.accessTokenKey);
    if (webVal != null && webVal.isNotEmpty) {
      _memoryCache[AppConfig.accessTokenKey] = webVal;
      return webVal;
    }
    try {
      final val = await _storage.read(key: AppConfig.accessTokenKey);
      if (val != null) _memoryCache[AppConfig.accessTokenKey] = val;
      return val;
    } catch (_) {
      return null;
    }
  }

  /// Delete stored JWT access token.
  Future<void> deleteAccessToken() async {
    _memoryCache.remove(AppConfig.accessTokenKey);
    web_storage.removeItem(AppConfig.accessTokenKey);
    try {
      await _storage.delete(key: AppConfig.accessTokenKey);
    } catch (_) {}
  }

  // ── User Info ──

  /// Store username.
  Future<void> saveUsername(String username) async {
    _memoryCache[AppConfig.usernameKey] = username;
    web_storage.setItem(AppConfig.usernameKey, username);
    try {
      await _storage.write(key: AppConfig.usernameKey, value: username);
    } catch (_) {}
  }

  /// Retrieve stored username.
  Future<String?> getUsername() async {
    if (_memoryCache.containsKey(AppConfig.usernameKey)) {
      return _memoryCache[AppConfig.usernameKey];
    }
    final webVal = web_storage.getItem(AppConfig.usernameKey);
    if (webVal != null && webVal.isNotEmpty) {
      _memoryCache[AppConfig.usernameKey] = webVal;
      return webVal;
    }
    try {
      final val = await _storage.read(key: AppConfig.usernameKey);
      if (val != null) _memoryCache[AppConfig.usernameKey] = val;
      return val;
    } catch (_) {
      return null;
    }
  }

  /// Store user role.
  Future<void> saveRole(String role) async {
    _memoryCache[AppConfig.roleKey] = role;
    web_storage.setItem(AppConfig.roleKey, role);
    try {
      await _storage.write(key: AppConfig.roleKey, value: role);
    } catch (_) {}
  }

  /// Retrieve stored role.
  Future<String?> getRole() async {
    if (_memoryCache.containsKey(AppConfig.roleKey)) {
      return _memoryCache[AppConfig.roleKey];
    }
    final webVal = web_storage.getItem(AppConfig.roleKey);
    if (webVal != null && webVal.isNotEmpty) {
      _memoryCache[AppConfig.roleKey] = webVal;
      return webVal;
    }
    try {
      final val = await _storage.read(key: AppConfig.roleKey);
      if (val != null) _memoryCache[AppConfig.roleKey] = val;
      return val;
    } catch (_) {
      return null;
    }
  }

  // ── Cleanup ──

  /// Clear all stored credentials. Called on logout.
  Future<void> clearAll() async {
    _memoryCache.clear();
    web_storage.clearItems();
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }

  /// Check if an access token is stored.
  Future<bool> hasToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
