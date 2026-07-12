import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/meeting.dart';

/// Persists meetings as JSON files under a per-user directory.
///
/// Every account gets its own subtree at `<documents>/users/<userId>/`, so
/// signing in as a different user never surfaces the previous user's
/// meetings, recordings, folders or search history. A [userId] of `null`
/// (signed out) falls back to a `_anonymous` subtree rather than the
/// documents root, so nothing is ever written where a later version would
/// mistake it for legacy data.
///
/// Note this is isolation, not encryption: the files remain readable to
/// anything that can read the app's sandbox.
class StorageService {
  static const _filename = 'meetings.json';
  static const _foldersFilename = 'folders.json';
  static const _recentSearchesFilename = 'recent_searches.json';
  static const _scheduledFilename = 'scheduled_meetings.json';
  static const _recordingsDirname = 'recordings';

  final String? userId;

  StorageService({this.userId});

  Future<Directory> _userDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final scope = userId ?? '_anonymous';
    final userDir = Directory(p.join(dir.path, 'users', scope));
    if (!await userDir.exists()) await userDir.create(recursive: true);
    return userDir;
  }

  Future<File> _getFile(String filename) async {
    final dir = await _userDir();
    return File(p.join(dir.path, filename));
  }

  /// Absolute path to this user's recordings directory, created on demand.
  Future<Directory> recordingsDir() async {
    final dir = await _userDir();
    final recordings = Directory(p.join(dir.path, _recordingsDirname));
    if (!await recordings.exists()) await recordings.create(recursive: true);
    return recordings;
  }

  /// Moves data written by versions that stored everything at the documents
  /// root into this user's directory.
  ///
  /// The move is its own guard: once the legacy files are gone the next user
  /// to sign in finds nothing to claim, so the first account to sign in after
  /// upgrading adopts the old data and no later account can. Anything already
  /// present in the user's directory wins and is never overwritten.
  Future<void> migrateLegacyData() async {
    if (userId == null) return;
    try {
      final root = await getApplicationDocumentsDirectory();
      final dest = await _userDir();

      for (final name in [
        _filename,
        _foldersFilename,
        _recentSearchesFilename,
      ]) {
        final legacy = File(p.join(root.path, name));
        final target = File(p.join(dest.path, name));
        if (await legacy.exists() && !await target.exists()) {
          await legacy.rename(target.path);
        }
      }

      final legacyRecordings = Directory(p.join(root.path, _recordingsDirname));
      final targetRecordings = Directory(p.join(dest.path, _recordingsDirname));
      if (await legacyRecordings.exists() && !await targetRecordings.exists()) {
        await legacyRecordings.rename(targetRecordings.path);
      }
    } catch (e) {
      debugPrint('StorageService.migrateLegacyData error: $e');
    }
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

  Future<List<dynamic>> loadScheduledMeetings() async {
    try {
      final file = await _getFile(_scheduledFilename);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      return jsonDecode(content) as List<dynamic>;
    } catch (e) {
      debugPrint('StorageService.loadScheduledMeetings error: $e');
      return [];
    }
  }

  Future<void> saveScheduledMeetings(List<dynamic> scheduled) async {
    try {
      final file = await _getFile(_scheduledFilename);
      await file.writeAsString(jsonEncode(scheduled));
    } catch (e) {
      debugPrint('StorageService.saveScheduledMeetings error: $e');
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
    final Map<String, int> sizes = {
      'recordings': 0,
      'metadata': 0,
      'history': 0,
    };
    try {
      final recordingsDirectory = await recordingsDir();
      if (await recordingsDirectory.exists()) {
        await for (final file in recordingsDirectory.list(recursive: true)) {
          if (file is File)
            sizes['recordings'] = sizes['recordings']! + await file.length();
        }
      }

      // Metadata (meetings.json + folders.json)
      final meetingsFile = await _getFile(_filename);
      if (await meetingsFile.exists())
        sizes['metadata'] = sizes['metadata']! + await meetingsFile.length();
      final foldersFile = await _getFile(_foldersFilename);
      if (await foldersFile.exists())
        sizes['metadata'] = sizes['metadata']! + await foldersFile.length();

      // History
      final historyFile = await _getFile(_recentSearchesFilename);
      if (await historyFile.exists())
        sizes['history'] = sizes['history']! + await historyFile.length();
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
      if (recordings) {
        final recordingsDirectory = await recordingsDir();
        if (await recordingsDirectory.exists())
          await recordingsDirectory.delete(recursive: true);
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
