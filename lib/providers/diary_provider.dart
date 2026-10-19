import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../services/diary_service.dart';

class DiaryProvider with ChangeNotifier {
  final DiaryService _service = DiaryService();
  List<DiaryEntry> _entries = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<DiaryEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Clear any active error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Load entries from MongoDB Atlas via API
  Future<void> loadEntries() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Migrate any legacy local storage notes to MongoDB on initial connection
      await _service.migrateLocalEntriesIfNeeded();

      _entries = await _service.loadEntries();
      // Ensure newest entries appear first
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

  /// Create a new diary note in MongoDB via API
  Future<void> addEntry(String title, String content) async {
    try {
      final newEntry = await _service.createEntry(title, content);
      _entries.insert(0, newEntry);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('DiaryProvider.addEntry error: $e');
      rethrow;
    }
  }

  /// Update an existing note in MongoDB via API
  Future<void> updateEntry(String id, String newTitle, String newContent) async {
    try {
      final updated = await _service.updateEntry(id, newTitle, newContent);
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

  /// Delete a note in MongoDB via API
  Future<void> deleteEntry(String id) async {
    try {
      await _service.deleteEntry(id);
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
