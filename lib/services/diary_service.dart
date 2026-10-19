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
  static const String _localKey = 'diary_entries';
  static const String _migratedKey = 'diary_entries_migrated';
  static const Duration _timeout = Duration(seconds: 10);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Helper to interpret network / HTTP errors into clear, friendly messages
  String _friendlyErrorMessage(dynamic error) {
    if (error is SocketException) {
      return 'Network connection failed. Please ensure the backend server is running and accessible at ${ApiConfig.baseUrl}.';
    }
    if (error is TimeoutException) {
      return 'Server request timed out. Please verify your connection to ${ApiConfig.baseUrl}.';
    }
    if (error is DiaryApiException) {
      return error.message;
    }
    return 'An error occurred: $error';
  }

  /// Retrieve all diary notes from MongoDB via GET /api/notes
  Future<List<DiaryEntry>> loadEntries() async {
    final uri = Uri.parse(ApiConfig.notesEndpoint);

    try {
      final response = await http.get(uri, headers: _headers).timeout(_timeout);

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

        // Update local offline backup with the latest data from MongoDB
        await _saveOfflineCache(entries);

        return entries;
      } else {
        final message = _extractErrorMessage(response.body, 'Failed to fetch notes (${response.statusCode})');
        throw DiaryApiException(message, response.statusCode);
      }
    } catch (e) {
      debugPrint('DiaryService.loadEntries error: $e');
      // If server is unreachable, load from local cache if available so app remains usable offline
      final cached = await _loadOfflineCache();
      if (cached.isNotEmpty) {
        debugPrint('Serving ${cached.length} entries from offline cache due to connection issue.');
        return cached;
      }
      throw DiaryApiException(_friendlyErrorMessage(e));
    }
  }

  /// Create a new diary note in MongoDB via POST /api/notes
  Future<DiaryEntry> createEntry(String title, String content) async {
    final uri = Uri.parse(ApiConfig.notesEndpoint);
    final payload = json.encode({
      'title': title.trim(),
      'content': content.trim(),
    });

    try {
      final response = await http
          .post(uri, headers: _headers, body: payload)
          .timeout(_timeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final dynamic noteData = (decoded is Map<String, dynamic> && decoded['data'] != null)
            ? decoded['data']
            : decoded;

        return DiaryEntry.fromJson(noteData);
      } else {
        final message = _extractErrorMessage(response.body, 'Failed to save note (${response.statusCode})');
        throw DiaryApiException(message, response.statusCode);
      }
    } catch (e) {
      debugPrint('DiaryService.createEntry error: $e');
      throw DiaryApiException(_friendlyErrorMessage(e));
    }
  }

  /// Update an existing diary note in MongoDB via PUT /api/notes/:id
  Future<DiaryEntry> updateEntry(String id, String title, String content) async {
    final uri = Uri.parse('${ApiConfig.notesEndpoint}/$id');
    final payload = json.encode({
      'title': title.trim(),
      'content': content.trim(),
    });

    try {
      final response = await http
          .put(uri, headers: _headers, body: payload)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final dynamic noteData = (decoded is Map<String, dynamic> && decoded['data'] != null)
            ? decoded['data']
            : decoded;

        return DiaryEntry.fromJson(noteData);
      } else {
        final message = _extractErrorMessage(response.body, 'Failed to update note (${response.statusCode})');
        throw DiaryApiException(message, response.statusCode);
      }
    } catch (e) {
      debugPrint('DiaryService.updateEntry error: $e');
      throw DiaryApiException(_friendlyErrorMessage(e));
    }
  }

  /// Delete a diary note in MongoDB via DELETE /api/notes/:id
  Future<void> deleteEntry(String id) async {
    final uri = Uri.parse('${ApiConfig.notesEndpoint}/$id');

    try {
      final response = await http.delete(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      } else {
        final message = _extractErrorMessage(response.body, 'Failed to delete note (${response.statusCode})');
        throw DiaryApiException(message, response.statusCode);
      }
    } catch (e) {
      debugPrint('DiaryService.deleteEntry error: $e');
      throw DiaryApiException(_friendlyErrorMessage(e));
    }
  }

  /// Migrate any existing local SharedPreferences notes to MongoDB Atlas
  /// This ensures existing user notes are never deleted or lost.
  Future<int> migrateLocalEntriesIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyMigrated = prefs.getBool(_migratedKey) ?? false;
    if (alreadyMigrated) {
      return 0;
    }

    final String? localData = prefs.getString(_localKey);
    if (localData == null || localData.isEmpty) {
      await prefs.setBool(_migratedKey, true);
      return 0;
    }

    try {
      final List<dynamic> localJsonList = json.decode(localData);
      int migratedCount = 0;

      for (final item in localJsonList) {
        final title = item['title']?.toString() ?? '';
        final content = item['content']?.toString() ?? '';
        if (title.isNotEmpty || content.isNotEmpty) {
          try {
            await createEntry(title.isEmpty ? 'Untitled' : title, content);
            migratedCount++;
          } catch (itemError) {
            debugPrint('Failed to migrate item "$title": $itemError');
          }
        }
      }

      // Mark migration complete so we don't duplicate on subsequent app launches
      await prefs.setBool(_migratedKey, true);
      debugPrint('Migrated $migratedCount local entries to MongoDB Atlas.');
      return migratedCount;
    } catch (e) {
      debugPrint('Error during local entries migration: $e');
      return 0;
    }
  }

  // --- Offline caching helpers for resilience ---

  Future<void> _saveOfflineCache(List<DiaryEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = json.encode(entries.map((e) => e.toJson()).toList());
      await prefs.setString(_localKey, data);
    } catch (e) {
      debugPrint('Offline cache save error: $e');
    }
  }

  Future<List<DiaryEntry>> _loadOfflineCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_localKey);
      if (data == null || data.isEmpty) return [];
      final List<dynamic> list = json.decode(data);
      return list.map((e) => DiaryEntry.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Offline cache load error: $e');
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
