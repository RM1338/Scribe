import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:android_id/android_id.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Resolves a stable identifier for this device, used to meter the free
/// transcription quota (see `supabase/migrations/0001_device_usage.sql`).
///
/// "Stable" here means *survives an app reinstall*, because a counter that a
/// user can reset by reinstalling meters nothing. That rules out the obvious
/// candidates:
///
///  * `AndroidDeviceInfo.id` is `Build.ID`, the firmware build label. It is
///    identical on every phone running the same ROM.
///  * iOS `identifierForVendor` resets once the last app from a vendor is
///    removed, so it does not survive an uninstall.
///
/// So: on Android, `Settings.Secure.ANDROID_ID`, which is scoped per app
/// signing key and persists until factory reset. Everywhere else, a random id
/// held in the platform keychain, which on iOS outlives app deletion.
///
/// None of this is tamper-proof -- a rooted device can change ANDROID_ID, and
/// a factory reset earns a fresh quota. It raises the cost of farming free
/// transcriptions; it does not make it impossible. The quota itself is only
/// ever decremented server-side.
class DeviceIdentity {
  DeviceIdentity({
    Future<String?> Function()? readPlatformId,
    FlutterSecureStorage? secureStorage,
    Random? random,
  }) : _readPlatformId = readPlatformId ?? _defaultPlatformId,
       _storage = secureStorage ?? const FlutterSecureStorage(),
       _random = random ?? Random.secure();

  static const _storageKey = 'scribe.device_id';

  final Future<String?> Function() _readPlatformId;
  final FlutterSecureStorage _storage;
  final Random _random;

  String? _cached;

  static Future<String?> _defaultPlatformId() async {
    if (Platform.isAndroid) return const AndroidId().getId();
    return null;
  }

  /// The device id, resolved once per process.
  Future<String> deviceId() async {
    final cached = _cached;
    if (cached != null) return cached;

    final platformId = await _tryReadPlatformId();
    if (platformId != null && platformId.trim().isNotEmpty) {
      return _cached = platformId.trim();
    }

    return _cached = await _persistedId();
  }

  Future<String?> _tryReadPlatformId() async {
    try {
      return await _readPlatformId();
    } catch (e) {
      // A missing platform channel must not block transcription entirely; fall
      // through to the generated id, which is still stable per install.
      debugPrint('DeviceIdentity: platform id unavailable ($e)');
      return null;
    }
  }

  Future<String> _persistedId() async {
    try {
      final existing = await _storage.read(key: _storageKey);
      if (existing != null && existing.isNotEmpty) return existing;

      final generated = _generateId();
      await _storage.write(key: _storageKey, value: generated);
      return generated;
    } catch (e) {
      // Keychain/keystore can be unavailable (locked device, unsupported
      // desktop). A per-process id still lets the user transcribe; it just
      // won't be metered accurately, which is the right way to fail.
      debugPrint('DeviceIdentity: secure storage unavailable ($e)');
      return _generateId();
    }
  }

  String _generateId() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
