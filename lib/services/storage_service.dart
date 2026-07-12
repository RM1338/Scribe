import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meeting.dart';
import 'cloud_store.dart';

/// Where a user's data lives depends on the platform:
///
///  * **Mobile/desktop** — [SyncedStorageService]: local JSON files remain the
///    source of truth (including audio), and every save mirrors the *text*
///    data (meetings minus audio, folders, schedules) to Supabase so other
///    devices can see it. Loads merge in records created elsewhere.
///  * **Web** — [CloudStorageService]: the browser has no usable filesystem,
///    so Supabase *is* the store. Recordings made on the web are transcribed
///    and summarized, but their audio is not persisted (text-only sync keeps
///    the backend inside the free tier).
///
/// The factory hides the choice; callers just construct [StorageService].
abstract class StorageService {
  factory StorageService({String? userId}) => kIsWeb
      ? CloudStorageService(userId: userId)
      : SyncedStorageService(userId: userId);

  String? get userId;

  Future<void> migrateLegacyData();
  Future<List<Meeting>> loadMeetings();
  Future<void> saveMeetings(List<Meeting> meetings);
  Future<List<dynamic>> loadFolders();
  Future<void> saveFolders(List<dynamic> folders);
  Future<List<dynamic>> loadScheduledMeetings();
  Future<void> saveScheduledMeetings(List<dynamic> scheduled);
  Future<List<String>> loadRecentSearches();
  Future<void> saveRecentSearches(List<String> searches);
  Future<Map<String, int>> getCacheSizes();
  Future<void> clearSelective({
    bool recordings = false,
    bool metadata = false,
    bool history = false,
  });

  /// Absolute path to this user's recordings directory, created on demand.
  /// Only meaningful where a filesystem exists; the web implementation throws
  /// (recording on web never asks for a directory — the recorder returns a
  /// blob URL instead).
  Future<Directory> recordingsDir();
}

/// A meeting's JSON with the device-specific audio path removed — the shape
/// everything cloud-bound must have.
Map<String, dynamic> _stripAudioPath(Map<String, dynamic> json) {
  final copy = Map<String, dynamic>.from(json);
  copy['audioFilePath'] = null;
  return copy;
}

// ─────────────────────────────────────────────────────────────────────────────
// Local files (the original implementation, unchanged in behaviour)
// ─────────────────────────────────────────────────────────────────────────────

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
class LocalStorageService implements StorageService {
  static const _filename = 'meetings.json';
  static const _foldersFilename = 'folders.json';
  static const _recentSearchesFilename = 'recent_searches.json';
  static const _scheduledFilename = 'scheduled_meetings.json';
  static const _recordingsDirname = 'recordings';

  @override
  final String? userId;

  LocalStorageService({this.userId});

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

  @override
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
  @override
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

  @override
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

  @override
  Future<void> saveMeetings(List<Meeting> meetings) async {
    try {
      final file = await _getFile(_filename);
      final data = meetings.map((m) => m.toJson()).toList();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('StorageService.saveMeetings error: $e');
    }
  }

  @override
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

  @override
  Future<void> saveFolders(List<dynamic> folders) async {
    try {
      final file = await _getFile(_foldersFilename);
      await file.writeAsString(jsonEncode(folders));
    } catch (e) {
      debugPrint('StorageService.saveFolders error: $e');
    }
  }

  @override
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

  @override
  Future<void> saveScheduledMeetings(List<dynamic> scheduled) async {
    try {
      final file = await _getFile(_scheduledFilename);
      await file.writeAsString(jsonEncode(scheduled));
    } catch (e) {
      debugPrint('StorageService.saveScheduledMeetings error: $e');
    }
  }

  @override
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

  @override
  Future<void> saveRecentSearches(List<String> searches) async {
    try {
      final file = await _getFile(_recentSearchesFilename);
      await file.writeAsString(jsonEncode(searches));
    } catch (e) {
      debugPrint('StorageService.saveRecentSearches error: $e');
    }
  }

  @override
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
          if (file is File) {
            sizes['recordings'] = sizes['recordings']! + await file.length();
          }
        }
      }

      // Metadata (meetings.json + folders.json)
      final meetingsFile = await _getFile(_filename);
      if (await meetingsFile.exists()) {
        sizes['metadata'] = sizes['metadata']! + await meetingsFile.length();
      }
      final foldersFile = await _getFile(_foldersFilename);
      if (await foldersFile.exists()) {
        sizes['metadata'] = sizes['metadata']! + await foldersFile.length();
      }

      // History
      final historyFile = await _getFile(_recentSearchesFilename);
      if (await historyFile.exists()) {
        sizes['history'] = sizes['history']! + await historyFile.length();
      }
    } catch (e) {
      debugPrint('StorageService.getCacheSizes error: $e');
    }
    return sizes;
  }

  @override
  Future<void> clearSelective({
    bool recordings = false,
    bool metadata = false,
    bool history = false,
  }) async {
    try {
      if (recordings) {
        final recordingsDirectory = await recordingsDir();
        if (await recordingsDirectory.exists()) {
          await recordingsDirectory.delete(recursive: true);
        }
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

// ─────────────────────────────────────────────────────────────────────────────
// Mobile/desktop: local files + cloud mirror
// ─────────────────────────────────────────────────────────────────────────────

/// Local storage that additionally keeps the user's cloud copy in step.
///
/// Loads pull the cloud tables and *merge*: records that exist only in the
/// cloud (made on the web or another phone) are adopted locally; on an id
/// conflict the local record wins. Saves write locally first — sync must
/// never cost the user their data — then mirror the whole list to the cloud
/// in the background.
///
/// Deletions are disambiguated with a sync ledger (ids this device knows made
/// it to the cloud, kept in SharedPreferences): a local record missing from
/// the cloud is *new* if it isn't in the ledger (push it) and *deleted
/// elsewhere* if it is (drop it locally too). Without that, a deletion on one
/// device would resurrect on the next sync from the other.
class SyncedStorageService implements StorageService {
  final LocalStorageService _local;
  final CloudStore _cloud = CloudStore();

  /// Whether this session has successfully pulled each table at least once.
  /// Until then, cloud pushes never delete rows — an offline start must not
  /// wipe records other devices created.
  final Map<String, bool> _pulled = {
    'meetings': false,
    'folders': false,
    'scheduled_meetings': false,
  };

  SyncedStorageService({String? userId})
      : _local = LocalStorageService(userId: userId);

  @override
  String? get userId => _local.userId;

  bool get _cloudEligible => userId != null && _cloud.isSignedIn;

  String _ledgerKey(String table) => 'synced_ids_${table}_$userId';

  Future<Set<String>> _ledger(String table) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_ledgerKey(table)) ?? const []).toSet();
  }

  Future<void> _saveLedger(String table, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_ledgerKey(table), ids.toList());
  }

  /// Core merge for one table. [localJson] is the device's list; returns the
  /// merged list (or null when nothing changed locally). Also pushes the
  /// merged result up and updates the ledger.
  Future<List<Map<String, dynamic>>?> _pullMerge(
    String table,
    List<Map<String, dynamic>> localJson,
  ) async {
    if (!_cloudEligible) return null;
    try {
      final cloud = await _cloud.fetchAll(table);
      _pulled[table] = true;

      final ledger = await _ledger(table);
      final cloudIds = cloud.map((j) => j['id'] as String).toSet();
      final localIds = localJson.map((j) => j['id'] as String).toSet();

      // Deleted elsewhere: we know it synced once, and the cloud no longer
      // has it.
      final removedIds = localIds
          .where((id) => ledger.contains(id) && !cloudIds.contains(id))
          .toSet();

      // Created elsewhere: in the cloud, unknown here.
      final adopted = cloud.where((j) => !localIds.contains(j['id'])).toList();

      final changed = removedIds.isNotEmpty || adopted.isNotEmpty;
      final merged = [
        for (final j in localJson)
          if (!removedIds.contains(j['id'])) j,
        ...adopted,
      ];

      // Everything in the merged list is (about to be) in the cloud.
      _cloud.tryReplaceAll(table, merged.map(_stripForTable(table)).toList());
      await _saveLedger(table, merged.map((j) => j['id'] as String).toSet());

      return changed ? merged : null;
    } catch (e) {
      debugPrint('SyncedStorage._pullMerge($table) failed: $e');
      return null;
    }
  }

  Map<String, dynamic> Function(Map<String, dynamic>) _stripForTable(
    String table,
  ) =>
      table == 'meetings' ? _stripAudioPath : (j) => j;

  /// Mirrors [records] up after a local save. Deletes cloud rows missing from
  /// the list only once a pull has succeeded this session.
  void _push(String table, List<Map<String, dynamic>> records) {
    if (!_cloudEligible) return;
    _cloud.tryReplaceAll(
      table,
      records.map(_stripForTable(table)).toList(),
      deleteMissing: _pulled[table] == true,
    );
    _saveLedger(table, records.map((j) => j['id'] as String).toSet());
  }

  // ── Meetings ──────────────────────────────────────────────

  @override
  Future<List<Meeting>> loadMeetings() async {
    final local = await _local.loadMeetings();
    final merged = await _pullMerge(
      'meetings',
      local.map((m) => m.toJson()).toList(),
    );
    if (merged == null) return local;

    final meetings = merged.map(Meeting.fromJson).toList()
      ..sort((a, b) {
        final at = a.recordedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.recordedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at); // newest first
      });
    await _local.saveMeetings(meetings);
    return meetings;
  }

  @override
  Future<void> saveMeetings(List<Meeting> meetings) async {
    await _local.saveMeetings(meetings);
    _push('meetings', meetings.map((m) => m.toJson()).toList());
  }

  // ── Folders ───────────────────────────────────────────────

  @override
  Future<List<dynamic>> loadFolders() async {
    final local = (await _local.loadFolders())
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final merged = await _pullMerge('folders', local);
    if (merged == null) return local;
    await _local.saveFolders(merged);
    return merged;
  }

  @override
  Future<void> saveFolders(List<dynamic> folders) async {
    await _local.saveFolders(folders);
    _push(
      'folders',
      folders.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }

  // ── Scheduled meetings ────────────────────────────────────

  @override
  Future<List<dynamic>> loadScheduledMeetings() async {
    final local = (await _local.loadScheduledMeetings())
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final merged = await _pullMerge('scheduled_meetings', local);
    if (merged == null) return local;
    await _local.saveScheduledMeetings(merged);
    return merged;
  }

  @override
  Future<void> saveScheduledMeetings(List<dynamic> scheduled) async {
    await _local.saveScheduledMeetings(scheduled);
    _push(
      'scheduled_meetings',
      scheduled.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }

  // ── Device-local concerns: straight delegation ────────────

  @override
  Future<void> migrateLegacyData() => _local.migrateLegacyData();
  @override
  Future<List<String>> loadRecentSearches() => _local.loadRecentSearches();
  @override
  Future<void> saveRecentSearches(List<String> searches) =>
      _local.saveRecentSearches(searches);
  @override
  Future<Map<String, int>> getCacheSizes() => _local.getCacheSizes();
  @override
  Future<void> clearSelective({
    bool recordings = false,
    bool metadata = false,
    bool history = false,
  }) =>
      _local.clearSelective(
        recordings: recordings,
        metadata: metadata,
        history: history,
      );
  @override
  Future<Directory> recordingsDir() => _local.recordingsDir();
}

// ─────────────────────────────────────────────────────────────────────────────
// Web: Supabase is the store
// ─────────────────────────────────────────────────────────────────────────────

/// Web storage: reads and writes go straight to the cloud tables. Recent
/// searches stay in the browser (SharedPreferences → localStorage) — they're
/// a device-local convenience, not user data worth syncing.
class CloudStorageService implements StorageService {
  final CloudStore _cloud = CloudStore();

  @override
  final String? userId;

  CloudStorageService({this.userId});

  String get _searchesKey => 'recent_searches_${userId ?? "_anonymous"}';

  @override
  Future<List<Meeting>> loadMeetings() async {
    if (userId == null) return [];
    try {
      final rows = await _cloud.fetchAll('meetings');
      return rows.map((j) => Meeting.fromJson(_stripAudioPath(j))).toList()
        ..sort((a, b) {
          final at = a.recordedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bt = b.recordedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bt.compareTo(at);
        });
    } catch (e) {
      debugPrint('CloudStorageService.loadMeetings error: $e');
      return [];
    }
  }

  @override
  Future<void> saveMeetings(List<Meeting> meetings) async {
    if (userId == null) return;
    try {
      await _cloud.replaceAll(
        'meetings',
        meetings.map((m) => _stripAudioPath(m.toJson())).toList(),
      );
    } catch (e) {
      debugPrint('CloudStorageService.saveMeetings error: $e');
    }
  }

  @override
  Future<List<dynamic>> loadFolders() async {
    if (userId == null) return [];
    try {
      return await _cloud.fetchAll('folders');
    } catch (e) {
      debugPrint('CloudStorageService.loadFolders error: $e');
      return [];
    }
  }

  @override
  Future<void> saveFolders(List<dynamic> folders) async {
    if (userId == null) return;
    try {
      await _cloud.replaceAll(
        'folders',
        folders.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    } catch (e) {
      debugPrint('CloudStorageService.saveFolders error: $e');
    }
  }

  @override
  Future<List<dynamic>> loadScheduledMeetings() async {
    if (userId == null) return [];
    try {
      return await _cloud.fetchAll('scheduled_meetings');
    } catch (e) {
      debugPrint('CloudStorageService.loadScheduledMeetings error: $e');
      return [];
    }
  }

  @override
  Future<void> saveScheduledMeetings(List<dynamic> scheduled) async {
    if (userId == null) return;
    try {
      await _cloud.replaceAll(
        'scheduled_meetings',
        scheduled.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    } catch (e) {
      debugPrint('CloudStorageService.saveScheduledMeetings error: $e');
    }
  }

  @override
  Future<List<String>> loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_searchesKey) ?? [];
  }

  @override
  Future<void> saveRecentSearches(List<String> searches) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_searchesKey, searches);
  }

  @override
  Future<void> migrateLegacyData() async {}

  @override
  Future<Map<String, int>> getCacheSizes() async =>
      {'recordings': 0, 'metadata': 0, 'history': 0};

  /// Only browser-local history is clearable from the web. Meetings and
  /// folders in the cloud are the user's primary copy of data synced from
  /// their phone — a "clear cache" button must never delete those.
  @override
  Future<void> clearSelective({
    bool recordings = false,
    bool metadata = false,
    bool history = false,
  }) async {
    if (history) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchesKey);
    }
  }

  @override
  Future<Directory> recordingsDir() async =>
      throw UnsupportedError('No filesystem on web');
}
