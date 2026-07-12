import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin data-access layer over the Supabase cloud-sync tables
/// (`meetings`, `folders`, `scheduled_meetings`).
///
/// Every table has the same shape: `(user_id, id, data jsonb)` with RLS
/// scoping rows to the signed-in user, so one class serves all three. Rows
/// hold each record's full JSON as the models serialize it — the reader just
/// hands the maps back to the same `fromJson` constructors the local files
/// use.
///
/// Audio never passes through here: meeting JSON is uploaded with
/// `audioFilePath` stripped (recordings stay on the device that made them).
class CloudStore {
  CloudStore();

  /// The Supabase client, or null when Supabase was never initialized (unit
  /// tests, or a failed startup). Sync silently disables rather than taking
  /// local storage down with it.
  SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isSignedIn => _clientOrNull?.auth.currentUser != null;

  /// All of this user's records from [table], newest first.
  /// Throws on network/auth failure — callers decide whether that's fatal
  /// (web, where cloud is the only store) or ignorable (mobile sync).
  Future<List<Map<String, dynamic>>> fetchAll(String table) async {
    final client = _clientOrNull;
    if (client == null) throw StateError('Supabase not initialized');
    final rows = await client
        .from(table)
        .select('data')
        .order('updated_at', ascending: false);
    return rows
        .map((r) => Map<String, dynamic>.from(r['data'] as Map))
        .toList();
  }

  /// Upserts [records] (each must carry an `id` key) into [table].
  Future<void> upsertAll(String table, List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;
    final client = _clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;
    await client.from(table).upsert([
      for (final data in records)
        {
          'user_id': userId,
          'id': data['id'],
          'data': data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
    ]);
  }

  /// Makes [table] contain exactly [records]: upserts them all, then deletes
  /// any of the user's rows whose id is no longer present. Used when the
  /// caller holds the authoritative full list (which is how the app saves —
  /// whole lists, not deltas).
  Future<void> replaceAll(
    String table,
    List<Map<String, dynamic>> records, {
    bool deleteMissing = true,
  }) async {
    final client = _clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;

    await upsertAll(table, records);

    if (!deleteMissing) return;
    final keepIds = records.map((r) => r['id'] as String).toList();
    var query = client.from(table).delete().eq('user_id', userId);
    if (keepIds.isNotEmpty) {
      query = query.not('id', 'in', keepIds);
    }
    await query;
  }

  Future<void> deleteById(String table, String id) async {
    final client = _clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;
    await client.from(table).delete().eq('user_id', userId).eq('id', id);
  }

  /// Fire-and-forget wrapper for mobile mirroring: sync must never break a
  /// local save (offline is normal there).
  void tryReplaceAll(
    String table,
    List<Map<String, dynamic>> records, {
    bool deleteMissing = true,
  }) {
    replaceAll(table, records, deleteMissing: deleteMissing).catchError((e) {
      debugPrint('CloudStore.tryReplaceAll($table) failed: $e');
    });
  }
}
