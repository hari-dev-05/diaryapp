import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../services/diary_service.dart';

class DiaryProvider with ChangeNotifier {
  final DiaryService _service = DiaryService();
  List<DiaryEntry> _entries = [];
  bool _isLoading = false;
  String? _errorMessage;

  String? _token;
  String? _userId;

  List<DiaryEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Update active authentication state (called via ChangeNotifierProxyProvider or explicitly)
  void updateAuth(String? token, String? userId) {
    final changedUser = _userId != userId;
    _token = token;
    _userId = userId;

    if (token == null || changedUser) {
      // Clear in-memory notes when logging out or switching users
      _entries = [];
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Explicitly clear notes and state on logout
  void clearNotesOnLogout() {
    _entries = [];
    _token = null;
    _userId = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear any active error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Load notes belonging to the authenticated user
  Future<void> loadEntries() async {
    if (_token == null || _userId == null) {
      _entries = [];
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _entries = await _service.loadEntries(
        token: _token,
        userId: _userId,
      );
      // Sort newest modified first
      _entries.sort((a, b) => b.dateModified.compareTo(a.dateModified));
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('DiaryProvider.loadEntries error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new diary note for the authenticated user
  Future<void> addEntry(String title, String content) async {
    if (_token == null || _userId == null) {
      throw DiaryApiException('Authentication required. Please log in.');
    }

    try {
      final newEntry = await _service.createEntry(
        token: _token,
        userId: _userId,
        title: title,
        content: content,
      );
      _entries.insert(0, newEntry);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('DiaryProvider.addEntry error: $e');
      rethrow;
    }
  }

  /// Update an existing note owned by the authenticated user
  Future<void> updateEntry(String id, String newTitle, String newContent) async {
    if (_token == null) {
      throw DiaryApiException('Authentication required. Please log in.');
    }

    try {
      final updated = await _service.updateEntry(
        token: _token,
        id: id,
        title: newTitle,
        content: newContent,
      );
      final index = _entries.indexWhere((e) => e.id == id);
      if (index != -1) {
        _entries[index] = updated;
        _entries.sort((a, b) => b.dateModified.compareTo(a.dateModified));
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('DiaryProvider.updateEntry error: $e');
      rethrow;
    }
  }

  /// Delete a note owned by the authenticated user
  Future<void> deleteEntry(String id) async {
    if (_token == null) {
      throw DiaryApiException('Authentication required. Please log in.');
    }

    try {
      await _service.deleteEntry(
        token: _token,
        id: id,
      );
      _entries.removeWhere((e) => e.id == id);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('DiaryProvider.deleteEntry error: $e');
      rethrow;
    }
  }
}
