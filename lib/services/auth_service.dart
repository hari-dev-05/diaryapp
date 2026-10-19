import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user_model.dart';

class AuthResult {
  final bool success;
  final User? user;
  final String? token;
  final String? errorMessage;

  AuthResult({
    required this.success,
    this.user,
    this.token,
    this.errorMessage,
  });
}

class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'auth_jwt_token';
  static const String _userIdKey = 'auth_user_id';
  static const String _userNameKey = 'auth_user_name';
  static const String _userEmailKey = 'auth_user_email';
  static const Duration _timeout = Duration(seconds: 12);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Read stored JWT access token
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (e) {
      debugPrint('Error reading auth token: $e');
      return null;
    }
  }

  /// Read locally stored user profile
  Future<User?> getSavedUser() async {
    try {
      final id = await _storage.read(key: _userIdKey);
      final name = await _storage.read(key: _userNameKey);
      final email = await _storage.read(key: _userEmailKey);

      if (id != null && name != null && email != null) {
        return User(id: id, name: name, email: email);
      }
      return null;
    } catch (e) {
      debugPrint('Error reading saved user: $e');
      return null;
    }
  }

  /// Save token and user data in secure storage
  Future<void> saveAuthData({required String token, required User user}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: user.id);
    await _storage.write(key: _userNameKey, value: user.name);
    await _storage.write(key: _userEmailKey, value: user.email);
  }

  /// Clear all stored authentication credentials
  Future<void> clearAuthData() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userIdKey);
      await _storage.delete(key: _userNameKey);
      await _storage.delete(key: _userEmailKey);
    } catch (e) {
      debugPrint('Error clearing auth data: $e');
    }
  }

  /// Register a new user account
  Future<AuthResult> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.authSignupEndpoint);
      final payload = json.encode({
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      });

      final response = await http
          .post(uri, headers: _headers, body: payload)
          .timeout(_timeout);

      final dynamic decoded = json.decode(response.body);

      if (response.statusCode == 201 && decoded['success'] == true) {
        final token = decoded['token']?.toString() ?? '';
        final user = User.fromJson(decoded['user']);

        await saveAuthData(token: token, user: user);
        return AuthResult(success: true, token: token, user: user);
      } else {
        final message = decoded['message']?.toString() ??
            'Registration failed (${response.statusCode})';
        return AuthResult(success: false, errorMessage: message);
      }
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: _friendlyErrorMessage(e),
      );
    }
  }

  /// Authenticate an existing user
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.authLoginEndpoint);
      final payload = json.encode({
        'email': email.trim().toLowerCase(),
        'password': password,
      });

      final response = await http
          .post(uri, headers: _headers, body: payload)
          .timeout(_timeout);

      final dynamic decoded = json.decode(response.body);

      if (response.statusCode == 200 && decoded['success'] == true) {
        final token = decoded['token']?.toString() ?? '';
        final user = User.fromJson(decoded['user']);

        await saveAuthData(token: token, user: user);
        return AuthResult(success: true, token: token, user: user);
      } else {
        final message = decoded['message']?.toString() ??
            'Login failed (${response.statusCode})';
        return AuthResult(success: false, errorMessage: message);
      }
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: _friendlyErrorMessage(e),
      );
    }
  }

  /// Verify existing token against /api/auth/me
  Future<User?> verifyToken(String token) async {
    try {
      final uri = Uri.parse(ApiConfig.authMeEndpoint);
      final response = await http.get(uri, headers: {
        ..._headers,
        'Authorization': 'Bearer $token',
      }).timeout(_timeout);

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        if (decoded['success'] == true && decoded['user'] != null) {
          final user = User.fromJson(decoded['user']);
          return user;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Token verification error: $e');
      return null;
    }
  }

  String _friendlyErrorMessage(dynamic error) {
    if (error is SocketException) {
      return 'Cannot connect to server. Please check your network connection.';
    }
    if (error is TimeoutException) {
      return 'Connection timed out. Please try again.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
