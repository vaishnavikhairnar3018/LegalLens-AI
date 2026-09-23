/// Application configuration constants.
///
/// All environment-specific values are centralized here.
/// In production, these should be loaded from build-time environment variables.
library;

import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._(); // Prevent instantiation

  /// Backend API base URL with automatic platform detection.
  /// - Web (Laptop browser): http://localhost:8000
  /// - Web (Mobile phone browser over Wi-Fi): http://<host>:8000
  /// - Android Device over Wi-Fi: http://10.244.134.104:8000
  static String get apiBaseUrl {
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : '127.0.0.1';
      final port = Uri.base.port;
      final scheme = Uri.base.scheme.isNotEmpty ? Uri.base.scheme : 'http';
      if (port == 8443) {
        return '$scheme://$host:$port';
      }
      return 'http://$host:8000';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return 'http://10.244.134.104:8000';
      case TargetPlatform.macOS:
        return 'http://localhost:8000';
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        return 'http://127.0.0.1:8000';
    }
  }

  /// API version prefix
  static const String apiPrefix = '/api/v1';

  /// Full API URL
  static String get apiUrl => '$apiBaseUrl$apiPrefix';

  /// Connection timeout in milliseconds
  static const int connectTimeout = 15000;

  /// Receive timeout in milliseconds
  static const int receiveTimeout = 60000; // OCR can take time

  /// Maximum upload file size in bytes (10MB)
  static const int maxUploadSizeBytes = 10 * 1024 * 1024;

  /// Secure storage keys
  static const String accessTokenKey = 'lensescan_access_token';
  static const String usernameKey = 'lensescan_username';
  static const String roleKey = 'lensescan_role';
}
