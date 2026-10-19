import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/diary_entry.dart';

class DiaryApiException implements Exception {
  final String message;
  final int? statusCode;

  DiaryApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class DiaryService {
  static const Duration _timeout = Duration(seconds: 10);

  Map<String, String> _buildHeaders(String? token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  /// User-specific offline cache key to guarantee cross-user data isolation
  String _userCacheKey(String userId) => 'diary_entries_user_$userId';

  /// Safely retrieves active base URL for error messages
  String get _safeBaseUrl {
    try {
      return ApiConfig.baseUrl;
    } catch (_) {
      return 'the backend';
    }
  }

  /// Helper to format network / HTTP / configuration errors into friendly messages
  String _friendlyErrorMessage(dynamic error) {
    if (error is StateError) {
      return error.message;
    }
    if (error is SocketException) {
      return 'Network connection failed. Please ensure the backend is reachable at $_safeBaseUrl.';
    }
    if (error is TimeoutException) {
      return 'Server request timed out. Please verify your connection to $_safeBaseUrl.';
    }
    if (error is DiaryApiException) {
      return error.message;
    }
    return 'An error occurred: $error';
  }

  /// Retrieve diary notes belonging exclusively to the authenticated user
  Future<List<DiaryEntry>> loadEntries({
    required String? token,
    required String? userId,
  }) async {
    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      throw DiaryApiException('Authentication required. Please log in to view your notes.', 401);
    }

    try {
      final uri = Uri.parse(ApiConfig.notesEndpoint);
      final response = await http
          .get(uri, headers: _buildHeaders(token))
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = json.decode(response.body);
        List<dynamic> list;

        if (decoded is Map<String, dynamic> && decoded['data'] is List) {
          list = decoded['data'];
        } else if (decoded is List) {
          list = decoded;
        } else {
          list = [];
        }

        final entries = list.map((item) => DiaryEntry.fromJson(item)).toList();

        // Update user-isolated offline cache with fresh notes
        await _saveUserOfflineCache(userId, entries);

        return entries;
      } else if (response.statusCode == 401) {
        throw DiaryApiException('Session expired or unauthorized. Please log in again.', 401);
      } else {
        final message = _extractErrorMessage(
            response.body, 'Failed to fetch notes (${response.statusCode})');
        throw DiaryApiException(message, response.statusCode);
      }
    } catch (e) {
      debugPrint('DiaryService.loadEntries error: $e');

      // Offline resilience: Serve only the current user's isolated local cache
      final cached = await _loadUserOfflineCache(userId);
      if (cached.isNotEmpty) {
        debugPrint('Serving ${cached.length} entries from offline cache for user $userId.');
        return cached;
      }
      throw DiaryApiException(_friendlyErrorMessage(e));
    }
  }

  /// Create a new diary note in MongoDB for the authenticated user
  Future<DiaryEntry> createEntry({
    required String? token,
    required String? userId,
    required String title,
    required String content,
  }) async {
    if (token == null || token.isEmpty) {
      throw DiaryApiException('Authentication required. Please log in.', 401);
    }

    try {
      final uri = Uri.parse(ApiConfig.notesEndpoint);
      final payload = json.encode({
        'title': title.trim(),
        'content': content.trim(),
      });

      final response = await http
          .post(uri, headers: _buildHeaders(token), body: payload)
          .timeout(_timeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final dynamic noteData =
            (decoded is Map<String, dynamic> && decoded['data'] != null)
                ? decoded['data']
                : decoded;

        return DiaryEntry.fromJson(noteData);
      } else if (response.statusCode == 401) {
        throw DiaryApiException('Session expired. Please log in again.', 401);
      } else {
        final message = _extractErrorMessage(
            response.body, 'Failed to save note (${response.statusCode})');
        throw DiaryApiException(message, response.statusCode);
      }
    } catch (e) {
      debugPrint('DiaryService.createEntry error: $e');
      throw DiaryApiException(_friendlyErrorMessage(e));
    }
  }

  /// Update an existing diary note belonging to the authenticated user
  Future<DiaryEntry> updateEntry({
    required String? token,
    required String id,
    required String title,
    required String content,
  }) async {
    if (token == null || token.isEmpty) {
      throw DiaryApiException('Authentication required. Please log in.', 401);
    }

    try {
      final uri = Uri.parse('${ApiConfig.notesEndpoint}/$id');
      final payload = json.encode({
        'title': title.trim(),
        'content': content.trim(),
      });

      final response = await http
          .put(uri, headers: _buildHeaders(token), body: payload)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final dynamic noteData =
            (decoded is Map<String, dynamic> && decoded['data'] != null)
                ? decoded['data']
                : decoded;

        return DiaryEntry.fromJson(noteData);
      } else if (response.statusCode == 404) {
        throw DiaryApiException('Note not found or you do not have permission to edit it.', 404);
      } else if (response.statusCode == 401) {
        throw DiaryApiException('Session expired. Please log in again.', 401);
      } else {
        final message = _extractErrorMessage(
            response.body, 'Failed to update note (${response.statusCode})');
        throw DiaryApiException(message, response.statusCode);
      }
    } catch (e) {
      debugPrint('DiaryService.updateEntry error: $e');
      throw DiaryApiException(_friendlyErrorMessage(e));
    }
  }

  /// Delete a diary note belonging to the authenticated user
  Future<void> deleteEntry({
    required String? token,
    required String id,
  }) async {
    if (token == null || token.isEmpty) {
      throw DiaryApiException('Authentication required. Please log in.', 401);
    }

    try {
      final uri = Uri.parse('${ApiConfig.notesEndpoint}/$id');
      final response = await http
          .delete(uri, headers: _buildHeaders(token))
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      } else if (response.statusCode == 404) {
        throw DiaryApiException('Note not found or you do not have permission to delete it.', 404);
      } else if (response.statusCode == 401) {
        throw DiaryApiException('Session expired. Please log in again.', 401);
      } else {
        final message = _extractErrorMessage(
            response.body, 'Failed to delete note (${response.statusCode})');
        throw DiaryApiException(message, response.statusCode);
      }
    } catch (e) {
      debugPrint('DiaryService.deleteEntry error: $e');
      throw DiaryApiException(_friendlyErrorMessage(e));
    }
  }

  // --- User-Isolated Offline Caching ---

  Future<void> _saveUserOfflineCache(String userId, List<DiaryEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = json.encode(entries.map((e) => e.toJson()).toList());
      await prefs.setString(_userCacheKey(userId), data);
    } catch (e) {
      debugPrint('User offline cache save error: $e');
    }
  }

  Future<List<DiaryEntry>> _loadUserOfflineCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_userCacheKey(userId));
      if (data == null || data.isEmpty) return [];
      final List<dynamic> list = json.decode(data);
      return list.map((e) => DiaryEntry.fromJson(e)).toList();
    } catch (e) {
      debugPrint('User offline cache load error: $e');
      return [];
    }
  }

  String _extractErrorMessage(String body, String defaultMessage) {
    try {
      final parsed = json.decode(body);
      if (parsed is Map && parsed['message'] != null) {
        return parsed['message'].toString();
      }
    } catch (_) {}
    return defaultMessage;
  }
}
