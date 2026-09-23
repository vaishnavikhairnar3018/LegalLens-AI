/// Dio HTTP client with auth interceptors and security headers.
///
/// All API calls go through this client to ensure:
/// - JWT Bearer token is attached to every authenticated request
/// - 401 responses trigger auto-logout
/// - Request/response logging for debugging
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import '../storage/secure_storage_service.dart';

/// Singleton Dio client for secure API communication.
class DioClient {
  DioClient._();
  static final DioClient instance = DioClient._();

  late final Dio _dio;
  bool _initialized = false;

  /// Initialize the Dio client. Must be called before making requests.
  Dio get dio {
    if (!_initialized) {
      _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiUrl,
          connectTimeout: const Duration(milliseconds: AppConfig.connectTimeout),
          receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeout),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      // Auth interceptor — attaches JWT to every request
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token =
                await SecureStorageService.instance.getAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            return handler.next(options);
          },
          onError: (error, handler) async {
            // Auto-logout on 401 Unauthorized
            if (error.response?.statusCode == 401) {
              await SecureStorageService.instance.clearAll();
              // The AuthProvider listener will handle UI redirect
            }
            return handler.next(error);
          },
        ),
      );

      // Logging interceptor (debug builds only)
      if (kDebugMode) {
        _dio.interceptors.add(
          LogInterceptor(
            requestBody: false, // Don't log file uploads
            responseBody: true,
            logPrint: (obj) => debugPrint('[DIO] $obj'),
          ),
        );
      }

      _initialized = true;
    }
    return _dio;
  }
}
