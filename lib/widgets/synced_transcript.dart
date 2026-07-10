import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../models/meeting.dart';
import '../theme/app_theme.dart';

/// Index of the segment being spoken at [position], or null if playback has not
/// reached the first segment yet.
///
/// Returns the last segment that has started. During a gap between segments --
/// silence, a pause, a speaker change -- that means the segment just finished
/// stays lit rather than the transcript going dark, which is what every lyrics
/// UI does and what reads as "where we are" to a listener.
///
/// Assumes [segments] is sorted by [MeetingSegment.start], which is how Whisper
/// returns them.
int? activeSegmentIndex(List<MeetingSegment> segments, Duration position) {
  if (segments.isEmpty) return null;

  final seconds = position.inMilliseconds / 1000.0;
  if (seconds < segments.first.start) return null;

  var low = 0;
  var high = segments.length - 1;
  var answer = 0;
  while (low <= high) {
    final mid = (low + high) ~/ 2;
    if (segments[mid].start <= seconds) {
      answer = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return answer;
}

enum TranscriptDensity {
  /// Inline under a meeting's Transcript tab, alongside speaker attribution.
  compact,

  /// Full-screen lyrics view on the now-playing screen.
  fullScreen,
}

/// A transcript that highlights the line currently being spoken and follows the
/// playhead, Apple Music style. Tapping a line seeks the audio to it.
///
/// Drives itself from [position] rather than from a [ChangeNotifier] so that a
/// playhead tick repaints only this widget. See [MeetingProvider.position].
class SyncedTranscript extends StatefulWidget {
  const SyncedTranscript({
    super.key,
    required this.segments,
    required this.position,
    required this.onSeek,
    this.density = TranscriptDensity.compact,
    this.headerBuilder,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 100),
  });

  final List<MeetingSegment> segments;
  final ValueListenable<Duration> position;
  final ValueChanged<Duration> onSeek;
  final TranscriptDensity density;

  /// Rendered above each line. Used by the Transcript tab for the speaker
  /// avatar, name, and timestamp; omitted in the full-screen view.
  final Widget Function(
    BuildContext context,
    MeetingSegment segment,
    int index,
  )?
  headerBuilder;

  final EdgeInsets padding;

  @override
  State<SyncedTranscript> createState() => _SyncedTranscriptState();
}

class _SyncedTranscriptState extends State<SyncedTranscript> {
  /// How long after the user stops scrolling before the view re-attaches to the
  /// playhead. Long enough to read a paragraph without being yanked away.
  static const _resumeFollowingAfter = Duration(seconds: 4);

  final _scrollController = ItemScrollController();

  /// Derived from the playhead, but only changes when the *line* changes -- a
  /// few times a minute rather than five times a second. The list subscribes to
  /// this, not to the raw position.
  final _activeIndex = ValueNotifier<int?>(null);

  bool _following = true;
  Timer? _resumeTimer;

  @override
  void initState() {
    super.initState();
    widget.position.addListener(_syncToPlayhead);
    _syncToPlayhead();
  }

  @override
  void didUpdateWidget(SyncedTranscript oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) {
      oldWidget.position.removeListener(_syncToPlayhead);
      widget.position.addListener(_syncToPlayhead);
    }
    // Segments arrive asynchronously while a recording transcribes.
    if (oldWidget.segments != widget.segments) _syncToPlayhead();
  }

  @override
  void dispose() {
    widget.position.removeListener(_syncToPlayhead);
    _resumeTimer?.cancel();
    _activeIndex.dispose();
    super.dispose();
  }

  void _syncToPlayhead() {
    final index = activeSegmentIndex(widget.segments, widget.position.value);
    if (index == _activeIndex.value) return;
    _activeIndex.value = index;
    if (index != null && _following) _scrollTo(index);
  }

  void _scrollTo(int index) {
    if (!mounted || !_scrollController.isAttached) return;
    _scrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      // Park the active line a little above centre, so the lines about to be
      // spoken are the ones in view.
      alignment: widget.density == TranscriptDensity.fullScreen ? 0.4 : 0.3,
    );
  }

  /// A finger on the list detaches it from the playhead; letting go re-attaches
  /// after a beat. Without this the view fights anyone trying to read ahead.
  void _onUserScroll() {
    _following = false;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeFollowingAfter, _resumeFollowing);
  }

  void _resumeFollowing() {
    if (!mounted) return;
    _following = true;
    final index = _activeIndex.value;
    if (index != null) _scrollTo(index);
  }

  void _onLineTapped(MeetingSegment segment) {
    widget.onSeek(Duration(milliseconds: (segment.start * 1000).round()));
    _resumeTimer?.cancel();
    _resumeFollowing();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // dragDetails is non-null only for a real finger drag, so our own
        // animated scrollTo doesn't detach us from the playhead.
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _onUserScroll();
        }
        return false;
      },
      child: ValueListenableBuilder<int?>(
        valueListenable: _activeIndex,
        builder: (context, activeIndex, _) {
          return ScrollablePositionedList.builder(
            itemScrollController: _scrollController,
            padding: widget.padding,
            itemCount: widget.segments.length,
            itemBuilder: (context, index) {
              final segment = widget.segments[index];
              return _TranscriptLine(
                segment: segment,
                isActive: index == activeIndex,
                density: widget.density,
                header: widget.headerBuilder?.call(context, segment, index),
                onTap: () => _onLineTapped(segment),
              );
            },
          );
        },
      ),
    );
  }
}

class _TranscriptLine extends StatelessWidget {
  const _TranscriptLine({
    required this.segment,
    required this.isActive,
    required this.density,
    required this.onTap,
    this.header,
  });

  final MeetingSegment segment;
  final bool isActive;
  final TranscriptDensity density;
  final VoidCallback onTap;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final isFullScreen = density == TranscriptDensity.fullScreen;

    final style = isFullScreen
        ? AppText.pageTitle.copyWith(
            fontSize: 24,
            height: 1.35,
            color: isActive ? context.appTextPrimary : context.appTextTertiary,
          )
        : AppText.cardTitle.copyWith(
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 16,
            height: 1.5,
            color: isActive ? context.appTextPrimary : context.appTextSecondary,
          );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(bottom: isFullScreen ? 20 : 24),
        padding: isFullScreen
            ? const EdgeInsets.symmetric(vertical: 4)
            : const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: isFullScreen
            ? null
            : BoxDecoration(
                color: isActive ? context.appPrimaryLight : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (header != null) ...[header!, const SizedBox(height: 8)],
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              style: style,
              child: Text(segment.text.trim()),
            ),
          ],
        ),
      ),
    );
  }
}
