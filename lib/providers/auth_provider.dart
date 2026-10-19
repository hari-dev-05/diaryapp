import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  String? _token;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Initialize and verify saved session on app startup
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final savedToken = await _authService.getToken();
      final savedUser = await _authService.getSavedUser();

      if (savedToken != null && savedToken.isNotEmpty) {
        // Optimistically set from local storage for fast startup
        _token = savedToken;
        _user = savedUser;

        // Verify token validity against the server in background
        final verifiedUser = await _authService.verifyToken(savedToken);
        if (verifiedUser != null) {
          _user = verifiedUser;
        } else {
          // Token is expired or invalid on the backend
          await logout();
        }
      } else {
        _token = null;
        _user = null;
      }
    } catch (e) {
      debugPrint('Auth status check error: $e');
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Register a new account
  Future<bool> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signup(
        name: name,
        email: email,
        password: password,
      );

      if (result.success && result.token != null && result.user != null) {
        _token = result.token;
        _user = result.user;
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.errorMessage ?? 'Signup failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Authenticate an existing account
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.login(
        email: email,
        password: password,
      );

      if (result.success && result.token != null && result.user != null) {
        _token = result.token;
        _user = result.user;
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.errorMessage ?? 'Login failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Log out the user and clear secure session
  Future<void> logout() async {
    await _authService.clearAuthData();
    _token = null;
    _user = null;
    _errorMessage = null;
    notifyListeners();
  }
}
