/// Auth service — handles login API calls and secure token management.
library;

import 'package:dio/dio.dart';

import '../api/dio_client.dart';
import '../api/api_endpoints.dart';
import '../storage/secure_storage_service.dart';

/// Authentication service for login, logout, and token management.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _storage = SecureStorageService.instance;

  /// Attempt login with username and password.
  ///
  /// On success, stores the JWT token securely and returns user info.
  /// On failure, throws a descriptive error message.
  Future<Map<String, String>> login(String username, String password) async {
    try {
      final response = await DioClient.instance.dio.post(
        ApiEndpoints.login,
        data: FormData.fromMap({
          'username': username,
          'password': password,
        }),
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['access_token'] as String;
      final role = data['role'] as String;
      final returnedUsername = data['username'] as String;

      // Store credentials securely
      await _storage.saveAccessToken(token);
      await _storage.saveUsername(returnedUsername);
      await _storage.saveRole(role);

      return {
        'username': returnedUsername,
        'role': role,
      };
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final detail = e.response!.data is Map
            ? e.response!.data['detail'] ?? 'Unknown error'
            : 'Unknown error';

        if (statusCode == 401) {
          throw 'Invalid username or password';
        } else if (statusCode == 403) {
          throw detail.toString();
        } else {
          throw 'Server error ($statusCode): $detail';
        }
      }
      throw 'Network error: Unable to connect to server. Please check your connection.';
    } catch (e) {
      if (e is String) rethrow;
      throw 'An unexpected error occurred: $e';
    }
  }

  /// Logout — clear all stored credentials.
  Future<void> logout() async {
    await _storage.clearAll();
  }

  /// Check if user has a stored valid token.
  Future<bool> isAuthenticated() async {
    return await _storage.hasToken();
  }

  /// Get stored username.
  Future<String?> getUsername() async {
    return await _storage.getUsername();
  }

  /// Get stored role.
  Future<String?> getRole() async {
    return await _storage.getRole();
  }
}
