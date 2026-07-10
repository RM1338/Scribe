import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:scribe/services/device_identity.dart';
import 'package:scribe/services/device_quota_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// Deterministic stand-in so generated ids are reproducible in tests.
class _SeededRandom implements Random {
  _SeededRandom(this._inner);
  final Random _inner;
  @override
  int nextInt(int max) => _inner.nextInt(max);
  @override
  bool nextBool() => _inner.nextBool();
  @override
  double nextDouble() => _inner.nextDouble();
}

class _FakeIdentity implements DeviceIdentity {
  _FakeIdentity(this.id);
  final String id;
  @override
  Future<String> deviceId() async => id;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceQuota.fromRpc', () {
    test('reads a table-returning RPC row', () {
      final quota = DeviceQuota.fromRpc([
        {'allowed': true, 'used': 3, 'quota': 10, 'remaining': 7}
      ]);

      expect(quota.allowed, isTrue);
      expect(quota.used, 3);
      expect(quota.quota, 10);
      expect(quota.remaining, 7);
    });

    test('accepts a bare map as well as a list', () {
      final quota = DeviceQuota.fromRpc(
        {'allowed': false, 'used': 10, 'quota': 10, 'remaining': 0},
      );
      expect(quota.allowed, isFalse);
      expect(quota.used, 10);
    });

    test('a consume response missing `allowed` is treated as denied', () {
      // Fail closed: a malformed or truncated response must never read as
      // permission to transcribe.
      final quota = DeviceQuota.fromRpc(const [], defaultAllowed: false);
      expect(quota.allowed, isFalse);
    });

    test('never reports negative remaining when quota is lowered below usage', () {
      final quota = DeviceQuota.fromRpc([
        {'allowed': false, 'used': 12, 'quota': 10}
      ]);
      expect(quota.remaining, 0);
    });
  });

  group('DeviceQuotaService', () {
    test('consume passes the device id and returns the new balance', () async {
      final calls = <(String, Map<String, dynamic>)>[];
      final service = DeviceQuotaService(
        identity: _FakeIdentity('device-abc'),
        invoke: (fn, params) async {
          calls.add((fn, params));
          return [
            {'allowed': true, 'used': 1, 'quota': 10, 'remaining': 9}
          ];
        },
      );

      final result = await service.consume();

      expect(calls.single.$1, 'consume_device_quota');
      expect(calls.single.$2, {'p_device_id': 'device-abc'});
      expect(result.remaining, 9);
    });

    test('consume throws once the allowance is spent', () async {
      final service = DeviceQuotaService(
        identity: _FakeIdentity('device-abc'),
        invoke: (_, _) async => [
          {'allowed': false, 'used': 10, 'quota': 10, 'remaining': 0}
        ],
      );

      await expectLater(
        service.consume(),
        throwsA(isA<QuotaExceededException>()
            .having((e) => e.quota, 'quota', 10)),
      );
    });

    test('fails closed when the migration is missing', () async {
      final service = DeviceQuotaService(
        identity: _FakeIdentity('device-abc'),
        invoke: (_, _) async => throw PostgrestException(
          message: 'Could not find the function',
          code: 'PGRST202',
        ),
      );

      await expectLater(
        service.consume(),
        throwsA(isA<QuotaUnavailableException>().having(
          (e) => e.detail,
          'detail',
          contains('not installed'),
        )),
      );
    });

    test('fails closed when the check errors for any other reason', () async {
      // Offline, expired session, RLS change -- an unenforceable allowance is
      // not an allowance, so none of these may wave transcription through.
      final service = DeviceQuotaService(
        identity: _FakeIdentity('device-abc'),
        invoke: (_, _) async => throw StateError('socket closed'),
      );

      await expectLater(
        service.consume(),
        throwsA(isA<QuotaUnavailableException>()),
      );
    });

    test('status reads without spending', () async {
      final calls = <String>[];
      final service = DeviceQuotaService(
        identity: _FakeIdentity('device-abc'),
        invoke: (fn, _) async {
          calls.add(fn);
          return [
            {'used': 4, 'quota': 10, 'remaining': 6}
          ];
        },
      );

      final result = await service.status();

      expect(calls, ['get_device_quota']);
      expect(result.used, 4);
      expect(result.remaining, 6);
    });
  });

  group('DeviceIdentity', () {
    test('prefers the platform id when one is available', () async {
      final identity = DeviceIdentity(
        readPlatformId: () async => '  android-id-1234  ',
        secureStorage: null,
      );
      expect(await identity.deviceId(), 'android-id-1234');
    });

    test('resolves once and caches', () async {
      var reads = 0;
      final identity = DeviceIdentity(readPlatformId: () async {
        reads++;
        return 'android-id-1234';
      });

      await identity.deviceId();
      await identity.deviceId();

      expect(reads, 1);
    });

    test('a blank platform id does not become the device id', () async {
      // An empty ANDROID_ID would otherwise collide every device onto one row.
      final identity = DeviceIdentity(
        readPlatformId: () async => '   ',
        random: _SeededRandom(Random(1)),
      );
      final id = await identity.deviceId();
      expect(id.trim(), isNotEmpty);
      expect(id.trim(), isNot('   '.trim()));
    });

    test('a throwing platform channel falls back rather than crashing', () async {
      final identity = DeviceIdentity(
        readPlatformId: () async => throw StateError('no channel'),
        random: _SeededRandom(Random(2)),
      );
      expect(await identity.deviceId(), isNotEmpty);
    });
  });
}
