import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribe/models/meeting.dart';
import 'package:scribe/widgets/synced_transcript.dart';

const _segments = <MeetingSegment>[
  MeetingSegment(start: 1.0, end: 3.0, text: 'First line'),
  MeetingSegment(start: 3.0, end: 5.5, text: 'Second line'),
  // Deliberate gap: nothing is spoken between 5.5s and 9s.
  MeetingSegment(start: 9.0, end: 12.0, text: 'Third line'),
];

Duration _at(double seconds) =>
    Duration(milliseconds: (seconds * 1000).round());

void main() {
  group('activeSegmentIndex', () {
    test('is null before the first segment starts', () {
      expect(activeSegmentIndex(_segments, _at(0.0)), isNull);
      expect(activeSegmentIndex(_segments, _at(0.99)), isNull);
    });

    test('is null for an empty transcript', () {
      expect(activeSegmentIndex(const [], _at(5)), isNull);
    });

    test('selects the segment containing the playhead', () {
      expect(activeSegmentIndex(_segments, _at(1.0)), 0);
      expect(activeSegmentIndex(_segments, _at(2.9)), 0);
      expect(activeSegmentIndex(_segments, _at(3.0)), 1);
      expect(activeSegmentIndex(_segments, _at(5.4)), 1);
      expect(activeSegmentIndex(_segments, _at(9.5)), 2);
    });

    test('holds the previous segment through a silent gap', () {
      expect(activeSegmentIndex(_segments, _at(6.0)), 1);
      expect(activeSegmentIndex(_segments, _at(8.99)), 1);
    });

    test('holds the last segment past the end of the audio', () {
      expect(activeSegmentIndex(_segments, _at(12.0)), 2);
      expect(activeSegmentIndex(_segments, _at(600.0)), 2);
    });

    test('binary search agrees with a linear scan over many segments', () {
      final many = List.generate(
        500,
        (i) => MeetingSegment(start: i * 2.0, end: i * 2.0 + 1.5, text: 'seg $i'),
      );

      for (var tenths = 0; tenths < 10000; tenths += 7) {
        final position = _at(tenths / 10);
        final expected = many.lastIndexWhere(
          (s) => s.start <= position.inMilliseconds / 1000.0,
        );
        expect(
          activeSegmentIndex(many, position),
          expected == -1 ? isNull : expected,
          reason: 'at ${position.inMilliseconds}ms',
        );
      }
    });
  });

  group('SyncedTranscript', () {
    late ValueNotifier<Duration> position;
    late List<Duration> seeks;

    setUp(() {
      position = ValueNotifier(Duration.zero);
      seeks = [];
    });

    tearDown(() => position.dispose());

    Future<void> pump(WidgetTester tester,
        {TranscriptDensity density = TranscriptDensity.compact}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncedTranscript(
              segments: _segments,
              position: position,
              density: density,
              onSeek: seeks.add,
            ),
          ),
        ),
      );
    }

    // ScrollablePositionedList renders its items into two stacked lists, so
    // every line matches twice. The copies are identical; take the first.
    TextStyle styleOf(WidgetTester tester, String text) {
      return tester
          .widget<AnimatedDefaultTextStyle>(find
              .ancestor(
                of: find.text(text).first,
                matching: find.byType(AnimatedDefaultTextStyle),
              )
              .first)
          .style;
    }

    testWidgets('bolds only the line being spoken', (tester) async {
      await pump(tester);

      position.value = _at(4.0);
      await tester.pumpAndSettle();

      expect(styleOf(tester, 'Second line').fontWeight, FontWeight.w700);
      expect(styleOf(tester, 'First line').fontWeight, FontWeight.w500);
      expect(styleOf(tester, 'Third line').fontWeight, FontWeight.w500);
    });

    testWidgets('moves the highlight as the playhead advances', (tester) async {
      await pump(tester);

      position.value = _at(2.0);
      await tester.pumpAndSettle();
      expect(styleOf(tester, 'First line').fontWeight, FontWeight.w700);

      position.value = _at(10.0);
      await tester.pumpAndSettle();
      expect(styleOf(tester, 'First line').fontWeight, FontWeight.w500);
      expect(styleOf(tester, 'Third line').fontWeight, FontWeight.w700);
    });

    testWidgets('nothing is highlighted before the first line', (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      for (final line in ['First line', 'Second line', 'Third line']) {
        expect(styleOf(tester, line).fontWeight, FontWeight.w500);
      }
    });

    testWidgets('tapping a line seeks to its start', (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Third line').first);
      await tester.pumpAndSettle();

      expect(seeks, [_at(9.0)]);
    });

    testWidgets('dims rather than bolds in the full-screen view',
        (tester) async {
      await pump(tester, density: TranscriptDensity.fullScreen);

      position.value = _at(4.0);
      await tester.pumpAndSettle();

      // Full-screen lines share one weight; the active one is distinguished by
      // color, the way a lyrics view does it.
      final active = styleOf(tester, 'Second line');
      final inactive = styleOf(tester, 'First line');
      expect(active.fontWeight, inactive.fontWeight);
      expect(active.color, isNot(inactive.color));
    });
  });
}
