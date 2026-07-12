import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// A published release, as recorded in the `app_release` Supabase table.
class AppRelease {
  final String latestVersion;
  final int latestBuild;
  final String downloadUrl;
  final String? releaseNotes;

  const AppRelease({
    required this.latestVersion,
    required this.latestBuild,
    required this.downloadUrl,
    this.releaseNotes,
  });

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    return AppRelease(
      latestVersion: json['latest_version'] as String,
      latestBuild: (json['latest_build'] as num?)?.toInt() ?? 0,
      downloadUrl: json['download_url'] as String,
      releaseNotes: json['release_notes'] as String?,
    );
  }
}

/// Checks Supabase for a newer published build so the app can prompt users to
/// download an update from the website. Deliberately fail-safe: any error
/// (offline, table missing, RLS) resolves to "no update" rather than throwing,
/// so a bad check never blocks the UI.
class UpdateService {
  SupabaseClient get _client => Supabase.instance.client;

  /// The platform key used in the `app_release` table, or null on platforms we
  /// don't distribute to (desktop), where there is nothing to check.
  static String? get platformKey {
    if (kIsWeb) return null; // the web app is always the latest deploy
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return null;
  }

  Future<AppRelease?> fetchLatest() async {
    final platform = platformKey;
    if (platform == null) return null;
    try {
      final row = await _client
          .from('app_release')
          .select()
          .eq('platform', platform)
          .maybeSingle();
      if (row == null) return null;
      return AppRelease.fromJson(row);
    } catch (_) {
      return null;
    }
  }
}

/// True when the published (version, build) is strictly newer than what is
/// running. Version is compared as semver (major.minor.patch); the build number
/// breaks ties for two releases that share a version string.
bool isUpdateAvailable({
  required String currentVersion,
  required int currentBuild,
  required String latestVersion,
  required int latestBuild,
}) {
  final cmp = compareVersions(latestVersion, currentVersion);
  if (cmp != 0) return cmp > 0;
  return latestBuild > currentBuild;
}

/// Compares two dotted version strings numerically. Returns a negative number
/// if [a] < [b], zero if equal, positive if [a] > [b]. Tolerates a trailing
/// `+build` suffix, missing segments ("1.2" == "1.2.0"), and stray non-digits.
int compareVersions(String a, String b) {
  final pa = _segments(a);
  final pb = _segments(b);
  final length = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < length; i++) {
    final ai = i < pa.length ? pa[i] : 0;
    final bi = i < pb.length ? pb[i] : 0;
    if (ai != bi) return ai.compareTo(bi);
  }
  return 0;
}

List<int> _segments(String version) {
  final withoutBuild = version.split('+').first.trim();
  return withoutBuild
      .split('.')
      .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}
