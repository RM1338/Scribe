import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:scribe/models/meeting.dart';
import 'package:scribe/services/storage_service.dart';

/// Redirects getApplicationDocumentsDirectory() at a throwaway temp dir.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

Meeting _meeting(String id) => Meeting(
      id: id,
      title: 'Meeting $id',
      team: 'Engineering',
      date: 'March 5, 2026',
      duration: '10 min',
      status: MeetingStatus.transcribed,
    );

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('scribe_storage_test');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('one user cannot read another user\'s meetings', () async {
    await StorageService(userId: 'user-a').saveMeetings([_meeting('a1')]);

    final bMeetings = await StorageService(userId: 'user-b').loadMeetings();
    expect(bMeetings, isEmpty);

    final aMeetings = await StorageService(userId: 'user-a').loadMeetings();
    expect(aMeetings.map((m) => m.id), ['a1']);
  });

  test('folders and recent searches are scoped per user too', () async {
    final a = StorageService(userId: 'user-a');
    await a.saveFolders([
      {'id': 'f1', 'name': 'Work'}
    ]);
    await a.saveRecentSearches(['budget']);

    final b = StorageService(userId: 'user-b');
    expect(await b.loadFolders(), isEmpty);
    expect(await b.loadRecentSearches(), isEmpty);
  });

  test('recordings live under the user directory, not the documents root',
      () async {
    final dir = await StorageService(userId: 'user-a').recordingsDir();
    expect(dir.path, p.join(root.path, 'users', 'user-a', 'recordings'));
    expect(await dir.exists(), isTrue);
  });

  test('legacy data is adopted by the first user to sign in, and only them',
      () async {
    // Simulate a pre-migration install: data sitting at the documents root.
    await File(p.join(root.path, 'meetings.json'))
        .writeAsString('[${_jsonFor('legacy-1')}]');
    await Directory(p.join(root.path, 'recordings')).create();
    await File(p.join(root.path, 'recordings', 'old.wav')).writeAsString('x');

    final first = StorageService(userId: 'user-a');
    await first.migrateLegacyData();
    expect((await first.loadMeetings()).map((m) => m.id), ['legacy-1']);
    expect(
      await File(p.join(root.path, 'users', 'user-a', 'recordings', 'old.wav'))
          .exists(),
      isTrue,
    );

    // The legacy files are gone, so a second user finds nothing to claim.
    final second = StorageService(userId: 'user-b');
    await second.migrateLegacyData();
    expect(await second.loadMeetings(), isEmpty);
  });

  test('migration never overwrites data the user already has', () async {
    await StorageService(userId: 'user-a').saveMeetings([_meeting('mine')]);
    await File(p.join(root.path, 'meetings.json'))
        .writeAsString('[${_jsonFor('legacy-1')}]');

    final a = StorageService(userId: 'user-a');
    await a.migrateLegacyData();

    expect((await a.loadMeetings()).map((m) => m.id), ['mine']);
  });

  test('signed-out writes go to _anonymous, never the documents root',
      () async {
    await StorageService(userId: null).saveMeetings([_meeting('anon')]);

    expect(await File(p.join(root.path, 'meetings.json')).exists(), isFalse);
    expect(
      await File(p.join(root.path, 'users', '_anonymous', 'meetings.json'))
          .exists(),
      isTrue,
    );
  });
}

String _jsonFor(String id) => '{"id":"$id","title":"Legacy","team":"T",'
    '"date":"March 5, 2026","duration":"1 min","status":"transcribed"}';
