import 'dart:io';
import 'package:flutter/foundation.dart';

/// Single source of truth for Backend REST API configuration.
///
/// Compile-time configuration is supplied via Flutter's `--dart-define`:
/// ```bash
/// # Development:
/// flutter run --dart-define=API_BASE_URL=https://api.diary.aitra.org/api
///
/// # Production APK:
/// flutter build apk --release --dart-define=API_BASE_URL=https://api.diary.aitra.org/api
/// ```
class ApiConfig {
  /// Compile-time environment variable read via [String.fromEnvironment].
  /// In release mode, this must be provided to prevent silent fallback to localhost.
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Optional runtime override (useful for testing or runtime configuration).
  static String? _customBaseUrl;

  /// Set custom base URL at runtime.
  static void setBaseUrl(String url) {
    _customBaseUrl = _normalizeUrl(url);
  }

  /// Removes trailing slashes to ensure consistent endpoint construction.
  static String _normalizeUrl(String url) {
    return url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  /// Returns whether a compile-time [API_BASE_URL] was supplied.
  static bool get hasEnvBaseUrl => _envBaseUrl.isNotEmpty;

  /// Resolves the single source of truth for the API base URL.
  ///
  /// Resolution precedence:
  /// 1. Explicit runtime override set via [setBaseUrl] (if specified).
  /// 2. Compile-time variable [API_BASE_URL] provided via `--dart-define=API_BASE_URL=...`.
  /// 3. In Release mode ([kReleaseMode]), if [API_BASE_URL] was not provided,
  ///    a descriptive [StateError] is thrown to prevent building/running a release APK
  ///    that silently defaults to localhost.
  /// 4. In Development/Debug mode, if [API_BASE_URL] was not provided, safe development
  ///    defaults are used:
  ///    - Android Emulator: `http://10.0.2.2:5000/api`
  ///    - Desktop / Web / Other: `http://localhost:5000/api`
  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }

    if (_envBaseUrl.isNotEmpty) {
      return _normalizeUrl(_envBaseUrl);
    }

    if (kReleaseMode) {
      throw StateError(
        'Missing required compile-time configuration: API_BASE_URL.\n'
        'When building for release, you must supply the production API URL via --dart-define:\n'
        '  flutter build apk --release --dart-define=API_BASE_URL=https://api.diary.aitra.org/api',
      );
    }

    // Safe development fallbacks when API_BASE_URL is omitted in debug mode:
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }

    try {
      if (Platform.isAndroid) {
        // Standard Android emulator loopback alias to host machine
        return 'http://10.0.2.2:5000/api';
      }
    } catch (_) {
      // Platform check unavailable in certain environments
    }

    return 'http://localhost:5000/api';
  }

  /// Primary diary notes endpoint (`<baseUrl>/notes`)
  static String get notesEndpoint => '$baseUrl/notes';

  /// Health check endpoint (`<baseUrl>/health`)
  static String get healthEndpoint => '$baseUrl/health';

  /// Authentication endpoints
  static String get authSignupEndpoint => '$baseUrl/auth/signup';
  static String get authLoginEndpoint => '$baseUrl/auth/login';
  static String get authMeEndpoint => '$baseUrl/auth/me';
}

