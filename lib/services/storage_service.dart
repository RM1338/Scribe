import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/meeting.dart';

/// Persists meetings as a JSON file in the app's documents directory.
class StorageService {
  static const _filename = 'meetings.json';
  static const _foldersFilename = 'folders.json';
  static const _recentSearchesFilename = 'recent_searches.json';

  Future<File> _getFile(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, filename));
  }

  Future<List<Meeting>> loadMeetings() async {
    try {
      final file = await _getFile(_filename);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final List<dynamic> data = jsonDecode(content) as List<dynamic>;
      return data
          .map((e) => Meeting.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('StorageService.loadMeetings error: $e');
      return [];
    }
  }

  Future<void> saveMeetings(List<Meeting> meetings) async {
    try {
      final file = await _getFile(_filename);
      final data = meetings.map((m) => m.toJson()).toList();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('StorageService.saveMeetings error: $e');
    }
  }

  Future<List<dynamic>> loadFolders() async {
    try {
      final file = await _getFile(_foldersFilename);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      return jsonDecode(content) as List<dynamic>;
    } catch (e) {
      debugPrint('StorageService.loadFolders error: $e');
      return [];
    }
  }

  Future<void> saveFolders(List<dynamic> folders) async {
    try {
      final file = await _getFile(_foldersFilename);
      await file.writeAsString(jsonEncode(folders));
    } catch (e) {
      debugPrint('StorageService.saveFolders error: $e');
    }
  }

  Future<List<String>> loadRecentSearches() async {
    try {
      final file = await _getFile(_recentSearchesFilename);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      return List<String>.from(jsonDecode(content));
    } catch (e) {
      debugPrint('StorageService.loadRecentSearches error: $e');
      return [];
    }
  }

  Future<void> saveRecentSearches(List<String> searches) async {
    try {
      final file = await _getFile(_recentSearchesFilename);
      await file.writeAsString(jsonEncode(searches));
    } catch (e) {
      debugPrint('StorageService.saveRecentSearches error: $e');
    }
  }

  Future<Map<String, int>> getCacheSizes() async {
    final Map<String, int> sizes = {'recordings': 0, 'metadata': 0, 'history': 0};
    try {
      final dir = await getApplicationDocumentsDirectory();
      
      // Recordings
      final recordingsDir = Directory(p.join(dir.path, 'recordings'));
      if (await recordingsDir.exists()) {
        await for (final file in recordingsDir.list(recursive: true)) {
          if (file is File) sizes['recordings'] = sizes['recordings']! + await file.length();
        }
      }

      // Metadata (meetings.json + folders.json)
      final meetingsFile = await _getFile(_filename);
      if (await meetingsFile.exists()) sizes['metadata'] = sizes['metadata']! + await meetingsFile.length();
      final foldersFile = await _getFile(_foldersFilename);
      if (await foldersFile.exists()) sizes['metadata'] = sizes['metadata']! + await foldersFile.length();

      // History
      final historyFile = await _getFile(_recentSearchesFilename);
      if (await historyFile.exists()) sizes['history'] = sizes['history']! + await historyFile.length();

    } catch (e) {
      debugPrint('StorageService.getCacheSizes error: $e');
    }
    return sizes;
  }

  Future<void> clearSelective({
    bool recordings = false,
    bool metadata = false,
    bool history = false,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      
      if (recordings) {
        final recordingsDir = Directory(p.join(dir.path, 'recordings'));
        if (await recordingsDir.exists()) await recordingsDir.delete(recursive: true);
      }

      if (metadata) {
        final meetingsFile = await _getFile(_filename);
        if (await meetingsFile.exists()) await meetingsFile.delete();
        final foldersFile = await _getFile(_foldersFilename);
        if (await foldersFile.exists()) await foldersFile.delete();
      }

      if (history) {
        final historyFile = await _getFile(_recentSearchesFilename);
        if (await historyFile.exists()) await historyFile.delete();
      }
    } catch (e) {
      debugPrint('StorageService.clearSelective error: $e');
    }
  }
}
