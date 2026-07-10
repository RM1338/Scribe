import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scribe/models/language.dart';
import 'package:scribe/models/meeting.dart';

Meeting _meeting({
  List<MeetingSegment> segments = const [],
  Map<String, MeetingTranslation> translations = const {},
  String? summary,
  List<String> actionItems = const [],
}) {
  return Meeting(
    id: 'm1',
    title: 'Standup',
    team: 'Core',
    date: 'Today',
    duration: '10m',
    status: MeetingStatus.transcribed,
    segments: segments,
    translations: translations,
    summary: summary,
    actionItems: actionItems,
  );
}

MeetingTranslation _translation(List<String> texts, {String code = 'hi'}) {
  return MeetingTranslation(
    languageCode: code,
    segmentTexts: texts,
    translatedAt: DateTime(2026, 7, 10),
  );
}

void main() {
  final segments = [
    const MeetingSegment(start: 0, end: 3, text: "Let's begin.", speaker: 'Speaker A'),
    const MeetingSegment(start: 3, end: 7, text: 'First item.', speaker: 'Speaker B'),
  ];

  group('segmentsIn', () {
    test('returns the original segments when no language is selected', () {
      final meeting = _meeting(segments: segments);
      expect(meeting.segmentsIn(null), same(meeting.segments));
    });

    test('substitutes translated text but preserves timings and speakers', () {
      final meeting = _meeting(
        segments: segments,
        translations: {'hi': _translation(['शुरू करते हैं।', 'पहला विषय।'])},
      );

      final translated = meeting.segmentsIn('hi');

      expect(translated.map((s) => s.text), ['शुरू करते हैं।', 'पहला विषय।']);
      // The player seeks and highlights off these, so they must survive intact.
      expect(translated.map((s) => s.start), [0, 3]);
      expect(translated.map((s) => s.end), [3, 7]);
      expect(translated.map((s) => s.speaker), ['Speaker A', 'Speaker B']);
    });

    test('falls back to the original when the translation is stale', () {
      // Simulates a re-transcription: two segments now, but the cached
      // translation was produced from three.
      final meeting = _meeting(
        segments: segments,
        translations: {'hi': _translation(['एक', 'दो', 'तीन'])},
      );

      expect(meeting.segmentsIn('hi'), same(meeting.segments));
      expect(meeting.hasTranslation('hi'), isFalse);
    });

    test('falls back to the original for a language never translated', () {
      final meeting = _meeting(segments: segments);
      expect(meeting.segmentsIn('ta'), same(meeting.segments));
    });
  });

  group('summary and action items', () {
    test('return translated content when present', () {
      final meeting = _meeting(
        segments: segments,
        summary: 'We shipped it.',
        actionItems: ['Email the client'],
        translations: {
          'hi': MeetingTranslation(
            languageCode: 'hi',
            segmentTexts: const ['a', 'b'],
            summary: 'हमने इसे भेज दिया।',
            actionItems: const ['ग्राहक को ईमेल करें'],
            translatedAt: DateTime(2026, 7, 10),
          ),
        },
      );

      expect(meeting.summaryIn('hi'), 'हमने इसे भेज दिया।');
      expect(meeting.actionItemsIn('hi'), ['ग्राहक को ईमेल करें']);
    });

    test('fall back to the original when the translation omitted them', () {
      final meeting = _meeting(
        segments: segments,
        summary: 'We shipped it.',
        actionItems: ['Email the client'],
        translations: {'hi': _translation(['a', 'b'])},
      );

      expect(meeting.summaryIn('hi'), 'We shipped it.');
      expect(meeting.actionItemsIn('hi'), ['Email the client']);
    });
  });

  group('json round-trip', () {
    test('preserves translations', () {
      final meeting = _meeting(
        segments: segments,
        translations: {'hi': _translation(['शुरू करते हैं।', 'पहला विषय।'])},
      );

      final restored = Meeting.fromJson(jsonDecode(meeting.toJsonString()));

      expect(restored.hasTranslation('hi'), isTrue);
      expect(restored.segmentsIn('hi').first.text, 'शुरू करते हैं।');
    });

    test('a meeting recorded before translation existed decodes cleanly', () {
      final legacy = jsonDecode(_meeting(segments: segments).toJsonString())
          as Map<String, dynamic>;
      legacy.remove('translations');

      final restored = Meeting.fromJson(legacy);

      expect(restored.translations, isEmpty);
      expect(restored.segmentsIn('hi'), same(restored.segments));
    });
  });

  group('AppLanguage.codeFor', () {
    // The bug this replaced: an unrecognised language silently transcribed the
    // audio as English instead of letting Whisper detect it.
    test('returns null rather than en for unknown or auto-detect', () {
      expect(AppLanguage.codeFor(AppLanguage.autoDetect), isNull);
      expect(AppLanguage.codeFor(null), isNull);
      expect(AppLanguage.codeFor('Klingon'), isNull);
    });

    test('maps known display names to ISO codes', () {
      expect(AppLanguage.codeFor('English'), 'en');
      expect(AppLanguage.codeFor('Hindi'), 'hi');
      expect(AppLanguage.codeFor('Tamil'), 'ta');
    });

    test('nameForCode round-trips, and degrades to the raw code', () {
      expect(AppLanguage.nameForCode('hi'), 'Hindi');
      expect(AppLanguage.nameForCode('EN'), 'English');
      expect(AppLanguage.nameForCode('xx'), 'xx');
    });

    test('search matches english and native names, case-insensitively', () {
      expect(AppLanguage.search('hind').single.code, 'hi');
      expect(AppLanguage.search('हिन्दी').single.code, 'hi');
      expect(AppLanguage.search('').length, AppLanguage.all.length);
    });
  });
}
