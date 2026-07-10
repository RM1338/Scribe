import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scribe/models/meeting.dart';
import 'package:scribe/services/pdf_export_service.dart';

Meeting _meeting({
  List<String> actionItems = const [],
  Set<int> completed = const {},
}) {
  return Meeting(
    id: 'm1',
    title: 'Q3 Planning / Review',
    team: 'Core',
    date: '10 Jul 2026',
    duration: '32m',
    status: MeetingStatus.transcribed,
    summary: 'We agreed to ship in August.',
    actionItems: actionItems,
    completedActionItems: completed,
    highlights: const ['Budget approved'],
    speakers: const ['Speaker A'],
    speakerMapping: const {'Speaker A': 'Ronel'},
    segments: const [
      MeetingSegment(start: 0, end: 3, text: "Let's begin.", speaker: 'Speaker A'),
      MeetingSegment(start: 3, end: 65, text: 'Ship in August.', speaker: 'Speaker A'),
    ],
  );
}

void main() {
  // PdfGoogleFonts probes the asset bundle before falling back to the network.
  // Without a binding that probe logs a scary (but harmless) error.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('completed action items', () {
    test('round-trip through JSON', () {
      final meeting = _meeting(
        actionItems: ['Email client', 'Book room', 'Draft budget'],
        completed: {0, 2},
      );

      final restored = Meeting.fromJson(jsonDecode(meeting.toJsonString()));

      expect(restored.isActionItemCompleted(0), isTrue);
      expect(restored.isActionItemCompleted(1), isFalse);
      expect(restored.isActionItemCompleted(2), isTrue);
      expect(restored.completedActionItemCount, 2);
    });

    test('a meeting saved before checkboxes existed decodes cleanly', () {
      final legacy = jsonDecode(_meeting(actionItems: ['Email client']).toJsonString())
          as Map<String, dynamic>;
      legacy.remove('completedActionItems');

      final restored = Meeting.fromJson(legacy);

      expect(restored.completedActionItems, isEmpty);
      expect(restored.isActionItemCompleted(0), isFalse);
    });

    test('an index past the end of the list is not counted as done', () {
      // Guards a re-summarise that shortens the list while ticks survive.
      final meeting = _meeting(actionItems: ['Only one'], completed: {0, 5});
      expect(meeting.completedActionItemCount, 1);
    });
  });

  group('PdfExportService', () {
    test('produces a valid PDF for a Latin-script meeting', () async {
      final bytes = await PdfExportService().build(_meeting(
        actionItems: ['Email client', 'Book room'],
        completed: {0},
      ));

      // Magic number: every PDF starts %PDF-.
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('renders a Devanagari translation without throwing', () async {
      final base = _meeting(actionItems: ['Email client']);
      final meeting = base.copyWith(
        translations: {
          'hi': MeetingTranslation(
            languageCode: 'hi',
            segmentTexts: const ['शुरू करते हैं।', 'अगस्त में भेजें।'],
            summary: 'हम अगस्त में भेजने पर सहमत हुए।',
            actionItems: const ['ग्राहक को ईमेल करें'],
            translatedAt: DateTime(2026, 7, 10),
          ),
        },
      );

      final bytes = await PdfExportService().build(meeting, languageCode: 'hi');

      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
