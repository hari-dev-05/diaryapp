import 'dart:io';
import 'package:flutter/foundation.dart';

/// Configuration for Backend REST API
class ApiConfig {
  /// Optional custom override (useful for physical device IP testing)
  static String? _customBaseUrl;

  /// Set custom base URL at runtime (e.g. 'http://192.168.1.100:5000/api')
  static void setBaseUrl(String url) {
    _customBaseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  /// Current active Base API URL
  /// 
  /// - Android Emulator: Uses 10.0.2.2:5000 (maps to host localhost)
  /// - Physical Android Phone: Use computer's local Wi-Fi IP (e.g. 192.168.X.X:5000)
  /// - Windows / macOS / Linux / Web: Uses localhost:5000
  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }

    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }

    try {
      if (Platform.isAndroid) {
        // Standard Android Emulator loopback to host machine
        return 'http://10.0.2.2:5000/api';
      }
    } catch (_) {
      // Platform check not available in some environments
    }

    return 'http://localhost:5000/api';
  }

  static String get notesEndpoint => '$baseUrl/notes';
}
