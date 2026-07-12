import 'package:flutter_test/flutter_test.dart';
import 'package:scribe/services/update_service.dart';

void main() {
  group('compareVersions', () {
    test('orders by major, minor, then patch', () {
      expect(compareVersions('1.0.0', '2.0.0'), lessThan(0));
      expect(compareVersions('1.2.0', '1.1.9'), greaterThan(0));
      expect(compareVersions('1.0.5', '1.0.4'), greaterThan(0));
      expect(compareVersions('1.0.0', '1.0.0'), 0);
    });

    test('treats missing trailing segments as zero', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.2.1', '1.2'), greaterThan(0));
    });

    test('ignores a +build suffix and stray non-digits', () {
      expect(compareVersions('1.2.0+5', '1.2.0+9'), 0);
      expect(compareVersions('v1.3.0', '1.2.0'), greaterThan(0));
    });

    test('compares double-digit segments numerically, not lexically', () {
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
    });
  });

  group('isUpdateAvailable', () {
    test('flags a newer version string', () {
      expect(
        isUpdateAvailable(
          currentVersion: '1.0.0',
          currentBuild: 1,
          latestVersion: '1.1.0',
          latestBuild: 1,
        ),
        isTrue,
      );
    });

    test('uses the build number to break a version tie', () {
      expect(
        isUpdateAvailable(
          currentVersion: '1.0.0',
          currentBuild: 3,
          latestVersion: '1.0.0',
          latestBuild: 4,
        ),
        isTrue,
      );
    });

    test('is false when current is up to date or ahead', () {
      expect(
        isUpdateAvailable(
          currentVersion: '1.0.0',
          currentBuild: 5,
          latestVersion: '1.0.0',
          latestBuild: 5,
        ),
        isFalse,
      );
      expect(
        isUpdateAvailable(
          currentVersion: '2.0.0',
          currentBuild: 1,
          latestVersion: '1.9.0',
          latestBuild: 9,
        ),
        isFalse,
      );
    });
  });
}
