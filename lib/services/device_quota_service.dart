import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_identity.dart';

/// Base type for "we did not spend a unit, and no work was done".
sealed class QuotaException implements Exception {
  const QuotaException();
}

/// Raised when the device has spent its free transcription allowance.
class QuotaExceededException extends QuotaException {
  const QuotaExceededException(this.quota);

  final int quota;

  @override
  String toString() =>
      'You have used all $quota free transcriptions on this device. '
      'Upgrade to keep transcribing.';
}

/// Raised when the quota couldn't be checked at all -- the migration hasn't
/// been applied, the device is offline, the session expired.
///
/// Fails closed. An allowance that stops being enforced the moment the check
/// errors is not an allowance, so this blocks transcription rather than waving
/// it through.
class QuotaUnavailableException extends QuotaException {
  const QuotaUnavailableException(this.detail);

  final String detail;

  @override
  String toString() => 'Could not verify your free transcriptions: $detail';
}

/// A snapshot of a device's free allowance, as reported by Postgres.
class DeviceQuota {
  const DeviceQuota({
    required this.allowed,
    required this.used,
    required this.quota,
    required this.remaining,
  });

  /// Whether the call that produced this snapshot was permitted to proceed.
  /// Always true for a read-only [DeviceQuotaService.status] check.
  final bool allowed;
  final int used;
  final int quota;
  final int remaining;

  /// The RPCs are table-returning, so PostgREST hands back a list of one row.
  factory DeviceQuota.fromRpc(dynamic payload, {bool defaultAllowed = true}) {
    final row = payload is List
        ? (payload.isEmpty ? const <String, dynamic>{} : payload.first as Map)
        : payload as Map;

    final quota = (row['quota'] as num?)?.toInt() ?? 0;
    final used = (row['used'] as num?)?.toInt() ?? 0;

    return DeviceQuota(
      allowed: row['allowed'] as bool? ?? defaultAllowed,
      used: used,
      quota: quota,
      // Trust the server's arithmetic when it sends it, but never report a
      // negative allowance if the quota is lowered below existing usage.
      remaining:
          (row['remaining'] as num?)?.toInt() ?? (quota - used).clamp(0, quota),
    );
  }
}

/// Client for the device-scoped free quota.
///
/// This class cannot grant quota -- it only relays what Postgres decided. The
/// counter lives behind a `security definer` function on a table with RLS and
/// no policies, so a modified client can call these functions but cannot read
/// or reset the underlying row. See the migration for the reasoning.
class DeviceQuotaService {
  DeviceQuotaService({
    required DeviceIdentity identity,
    Future<dynamic> Function(String fn, Map<String, dynamic> params)? invoke,
  }) : _identity = identity,
       _invoke = invoke ?? _defaultInvoke;

  final DeviceIdentity _identity;
  final Future<dynamic> Function(String, Map<String, dynamic>) _invoke;

  static Future<dynamic> _defaultInvoke(
    String fn,
    Map<String, dynamic> params,
  ) {
    return Supabase.instance.client.rpc(fn, params: params);
  }

  /// Reads the allowance without spending any.
  Future<DeviceQuota> status() async {
    final id = await _identity.deviceId();
    return DeviceQuota.fromRpc(
      await _invoke('get_device_quota', {'p_device_id': id}),
    );
  }

  /// Spends one transcription, or throws [QuotaExceededException] if none are
  /// left. The check and the decrement happen under one row lock server-side,
  /// so two concurrent recordings can't both slip through on the last unit.
  ///
  /// Throws [QuotaUnavailableException] if the check itself couldn't run.
  Future<DeviceQuota> consume() async {
    final id = await _identity.deviceId();

    final dynamic payload;
    try {
      payload = await _invoke('consume_device_quota', {'p_device_id': id});
    } on PostgrestException catch (e) {
      // PGRST202: the function isn't in the schema cache, i.e. the migration in
      // supabase/migrations/ has not been applied to this project.
      throw QuotaUnavailableException(
        e.code == 'PGRST202'
            ? 'the free-quota functions are not installed on the server'
            : e.message,
      );
    } catch (e) {
      throw QuotaUnavailableException(e.toString());
    }

    final result = DeviceQuota.fromRpc(payload, defaultAllowed: false);
    if (!result.allowed) throw QuotaExceededException(result.quota);
    return result;
  }
}
