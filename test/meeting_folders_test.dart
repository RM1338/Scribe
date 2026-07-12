import 'package:flutter_test/flutter_test.dart';
import 'package:scribe/models/meeting.dart';

Map<String, dynamic> _baseJson() => {
  'id': '1',
  'title': 'Standup',
  'team': 'Personal',
  'date': 'Jul 11',
  'duration': '12m',
  'status': 'transcribed',
};

void main() {
  group('Meeting folder membership', () {
    test('migrates a legacy single folderId into folderIds', () {
      final json = _baseJson()..['folderId'] = 'abc';
      final m = Meeting.fromJson(json);
      expect(m.folderIds, ['abc']);
    });

    test('reads folderIds when present and ignores legacy folderId', () {
      final json = _baseJson()
        ..['folderIds'] = ['a', 'b']
        ..['folderId'] = 'legacy';
      final m = Meeting.fromJson(json);
      expect(m.folderIds, ['a', 'b']);
    });

    test('defaults to no folders when neither field is present', () {
      expect(Meeting.fromJson(_baseJson()).folderIds, isEmpty);
    });

    test('round-trips multiple folders through toJson/fromJson', () {
      final original = Meeting.fromJson(_baseJson()).copyWith(
        folderIds: ['x', 'y', 'z'],
      );
      final restored = Meeting.fromJson(original.toJson());
      expect(restored.folderIds, ['x', 'y', 'z']);
    });

    test('toJson writes folderIds, not the legacy folderId key', () {
      final json = Meeting.fromJson(_baseJson())
          .copyWith(folderIds: ['x'])
          .toJson();
      expect(json['folderIds'], ['x']);
      expect(json.containsKey('folderId'), isFalse);
    });
  });
}
