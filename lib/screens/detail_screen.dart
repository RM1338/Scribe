import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/meeting_provider.dart';
import '../models/language.dart';
import '../models/meeting.dart';
import '../services/pdf_export_service.dart';
import '../widgets/language_picker.dart';
import '../widgets/synced_transcript.dart';

class DetailScreen extends StatefulWidget {
  final Meeting meeting;
  const DetailScreen({super.key, required this.meeting});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double? _dragProgress;

  /// Language the transcript is currently being *displayed* in, or null for the
  /// original. Purely a view preference -- the meeting keeps every translation
  /// it has ever fetched.
  String? _viewLanguageCode;

  final _pdf = PdfExportService();
  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingProvider>(
      builder: (context, provider, _) {
        final live = provider.allMeetings.firstWhere(
          (m) => m.id == widget.meeting.id,
          orElse: () => widget.meeting,
        );
        final isProcessing = provider.currentProcessingId == live.id;

        return Scaffold(
          backgroundColor: context.appBackground,
          appBar: _buildAppBar(context, live, provider),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Title Section
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(live.title, style: context.pageTitle),
                    const SizedBox(height: 8),
                    Text(
                      '${live.date} • ${live.duration}',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: context.appTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 2. Segmented Control (Tabs)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.appSurfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: context.appPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: context.appTextSecondary,
                    labelStyle: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    dividerColor:
                        Colors.transparent, // Remove default underline
                    tabs: const [
                      Tab(text: 'Transcript'),
                      Tab(text: 'Summary'),
                    ],
                  ),
                ),
              ),

              if (isProcessing)
                Padding(
                  padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
                  child: _ProcessingCard(provider: provider),
                ),

              const SizedBox(height: 20),

              // 3. Main Content Area (Tab Views)
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTranscriptView(context, live, provider),
                    _buildSummaryView(context, live, provider),
                  ],
                ),
              ),

              // 4. Persistent Audio Player
              if (live.audioFilePath != null)
                _buildAudioPlayer(context, live, provider),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    Meeting live,
    MeetingProvider provider,
  ) {
    return AppBar(
      backgroundColor: context.appBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.appSurface,
            shape: BoxShape.circle,
            border: Border.all(color: context.appSeparator),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.appTextPrimary,
            size: 16,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('Meeting Details', style: context.appBarTitle),
      actions: [
        // Building a PDF fetches a font on first use of a script, so it is not
        // always instant. Replace the menu rather than stack a dialog over it.
        if (_exportingPdf)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: context.appPrimary,
              ),
            ),
          )
        else
          PopupMenuButton<String>(
            color: context.appSurface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            icon: Icon(
              Icons.edit_outlined,
              color: context.appTextPrimary,
              size: 24,
            ),
            onSelected: (value) async {
              if (value == 'rename') {
                final newTitle = await _showRenameDialog(context, live.title);
                if (newTitle != null) provider.renameMeeting(live.id, newTitle);
              } else if (value == 'share') {
                await _shareAsPdf(live);
              } else if (value == 'delete') {
                final confirm = await _showDeleteConfirm(context);
                if (confirm == true) {
                  provider.deleteMeeting(live.id);
                  if (context.mounted) Navigator.pop(context);
                }
              } else if (value == 'move') {
                _showMoveToFolderDialog(context, provider, live);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'rename',
                child: Text('Rename', style: GoogleFonts.manrope()),
              ),
              PopupMenuItem(
                value: 'move',
                child: Text('Move to Folder', style: GoogleFonts.manrope()),
              ),
              PopupMenuItem(
                value: 'share',
                child: Text('Share as PDF', style: GoogleFonts.manrope()),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete',
                  style: GoogleFonts.manrope(color: Colors.red),
                ),
              ),
            ],
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSummaryView(
    BuildContext context,
    Meeting live,
    MeetingProvider provider,
  ) {
    // Follows whatever language the transcript tab is showing, so the two tabs
    // never disagree about which language you're reading the meeting in.
    final summary = live.summaryIn(_viewLanguageCode);
    final actionItems = live.actionItemsIn(_viewLanguageCode);
    final highlights = live.highlightsIn(_viewLanguageCode);
    final hasContent =
        (summary != null && summary.isNotEmpty) || actionItems.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        if (hasContent && live.segments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildTranslationBar(
              context,
              live,
              provider,
              horizontalPadding: 0,
            ),
          ),
        if (summary != null && summary.isNotEmpty)
          _buildSummaryCard(context, 'Smart Summary', Icons.lightbulb, summary),
        if (actionItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildActionItemsCard(context, live, actionItems, provider),
        ],
        if (highlights.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildHighlightsCard(context, highlights),
        ],
        if (!hasContent)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                provider.currentProcessingId == live.id
                    ? 'Generating summary…'
                    : 'No summary yet.',
                style: GoogleFonts.manrope(color: context.appTextSecondary),
              ),
            ),
          ),
        if (hasContent) const SizedBox(height: 16),
        // The user's own note lives here regardless of whether the AI produced
        // anything, so it's writable even while a recording is still processing.
        _NotesCard(meeting: live),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.appShadowSubtle,
        border: Border.all(
          color: context.appSeparator.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.appPrimary, size: 20),
              const SizedBox(width: 8),
              Text(title, style: context.sectionTitle),
            ],
          ),
          const SizedBox(height: 16),
          // We can try to parse Key Points or just display it with custom bullets
          ...text.split('\n').where((s) => s.trim().isNotEmpty).map((line) {
            final content = line.trim().replaceFirst(RegExp(r'^[-*•]\s*'), '');
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, right: 12.0),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: context.appPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      content,
                      style: GoogleFonts.manrope(
                        color: context.appTextSecondary,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionItemsCard(
    BuildContext context,
    Meeting live,
    List<String> items,
    MeetingProvider provider,
  ) {
    final done = live.completedActionItemCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.appShadowSubtle,
        border: Border.all(
          color: context.appSeparator.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: context.appTextPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('Action Items', style: context.sectionTitle),
              const Spacer(),
              Text(
                '$done/${items.length}',
                style: GoogleFonts.manrope(
                  color: context.appTextSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Indexed, because completion is stored by position -- see
          // Meeting.completedActionItems.
          for (var i = 0; i < items.length; i++)
            _ActionItemRow(
              text: items[i],
              completed: live.isActionItemCompleted(i),
              onToggle: () => provider.toggleActionItem(live.id, i),
            ),
        ],
      ),
    );
  }

  Widget _buildHighlightsCard(BuildContext context, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.appShadowSubtle,
        border: Border.all(
          color: context.appSeparator.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.star_outline_rounded,
                color: context.appTextPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('Highlights', style: context.sectionTitle),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, right: 12.0),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.manrope(
                        color: context.appTextSecondary,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptView(
    BuildContext context,
    Meeting live,
    MeetingProvider provider,
  ) {
    if (live.segments.isEmpty) {
      if (live.transcript != null && live.transcript!.isNotEmpty) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: context.appShadowSubtle,
                border: Border.all(
                  color: context.appSeparator.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
              child: Text(
                live.transcript!,
                style: GoogleFonts.manrope(
                  color: context.appTextPrimary,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
          ],
        );
      }
      return Center(
        child: Text(
          provider.currentProcessingId == live.id
              ? 'Transcribing…'
              : 'No transcript available.',
          style: GoogleFonts.manrope(color: context.appTextSecondary),
        ),
      );
    }

    // Substituting the text while keeping each segment's start/end is what lets
    // tap-to-seek and highlight-follows-audio work on a translated transcript
    // without SyncedTranscript knowing translation exists.
    final segments = live.segmentsIn(_viewLanguageCode);

    return Column(
      children: [
        _buildTranslationBar(context, live, provider),
        Expanded(
          child: SyncedTranscript(
            // Rebuild the list from scratch when the language flips, rather
            // than animating each line into a different script.
            key: ValueKey(_viewLanguageCode),
            segments: segments,
            position: provider.position,
            density: TranscriptDensity.compact,
            onSeek: (to) => _seekWithin(provider, live, to),
            headerBuilder: (context, segment, _) => _buildSpeakerHeader(
              context,
              live.id,
              segment,
              live.speakerMapping,
              provider,
            ),
          ),
        ),
      ],
    );
  }

  /// Language switcher above the transcript. Shows the original plus every
  /// language already translated, and a button to add another.
  Widget _buildTranslationBar(
    BuildContext context,
    Meeting live,
    MeetingProvider provider, {
    double horizontalPadding = 20,
  }) {
    final isTranslating = provider.isTranslating(live.id);
    final cached =
        live.translations.keys
            .where((code) => live.hasTranslation(code))
            .toList()
          ..sort();

    return Container(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _LanguageChip(
                  label: live.detectedLanguage != null
                      ? 'Original (${AppLanguage.nameForCode(live.detectedLanguage!)})'
                      : 'Original',
                  selected: _viewLanguageCode == null,
                  onTap: () => setState(() => _viewLanguageCode = null),
                ),
                for (final code in cached) ...[
                  const SizedBox(width: 8),
                  _LanguageChip(
                    label: AppLanguage.nameForCode(code),
                    selected: _viewLanguageCode == code,
                    onTap: () => setState(() => _viewLanguageCode = code),
                  ),
                ],
                const SizedBox(width: 8),
                _LanguageChip(
                  label: 'Translate',
                  icon: Icons.translate_rounded,
                  selected: false,
                  onTap: isTranslating
                      ? null
                      : () => _pickTranslationLanguage(live, provider),
                ),
              ],
            ),
          ),
          if (isTranslating) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: provider.translationProgress > 0
                          ? provider.translationProgress
                          : null,
                      minHeight: 4,
                      backgroundColor: context.appSeparator,
                      valueColor: AlwaysStoppedAnimation(context.appPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Translating ${(provider.translationProgress * 100).round()}%',
                  style: GoogleFonts.manrope(
                    color: context.appTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Exports in whatever language the screen is currently showing, so what the
  /// user shares is what they were just reading.
  Future<void> _shareAsPdf(Meeting live) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exportingPdf = true);

    try {
      final bytes = await _pdf.build(live, languageCode: _viewLanguageCode);
      await _pdf.share(bytes, live);
    } catch (_) {
      // Most likely a failed font fetch for a non-Latin script on a device that
      // is offline. Falling back to a Latin font would silently render a page
      // of blank boxes, so say what happened instead.
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't build the PDF. Check your connection and try again.",
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<void> _pickTranslationLanguage(
    Meeting live,
    MeetingProvider provider,
  ) async {
    final language = await showLanguagePicker(
      context,
      title: 'Translate transcript to',
      selectedCode: _viewLanguageCode,
    );
    if (language == null || !mounted) return;

    // Already have it: just switch the view, no network call.
    if (live.hasTranslation(language.code)) {
      setState(() => _viewLanguageCode = language.code);
      return;
    }

    final ok = await provider.translateMeeting(live.id, language.code);
    if (!mounted) return;

    if (ok) {
      setState(() => _viewLanguageCode = language.code);
    } else if (provider.translationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(provider.translationError!)));
      provider.clearTranslationError();
    }
  }

  /// Tapping a transcript line should work even when this meeting isn't the one
  /// loaded in the player. Guarded on the id because [playMeeting] toggles
  /// pause when handed the meeting already playing.
  Future<void> _seekWithin(
    MeetingProvider provider,
    Meeting live,
    Duration to,
  ) async {
    if (provider.currentlyPlayingId != live.id) {
      await provider.playMeeting(live);
    }
    await provider.seek(to);
  }

  String _formatTime(double seconds) {
    final m = seconds ~/ 60;
    final s = seconds.toInt() % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildSpeakerHeader(
    BuildContext context,
    String meetingId,
    MeetingSegment segment,
    Map<String, String> speakerMapping,
    MeetingProvider provider,
  ) {
    final speakerId = segment.speaker;
    final displayName = speakerId != null
        ? (speakerMapping[speakerId] ?? speakerId)
        : 'Unknown';
    // Generate initials for avatar
    final initials = displayName
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();

    return Row(
      children: [
        GestureDetector(
          onTap: () async {
            final newName = await _showRenameSpeakerDialog(
              context,
              displayName,
            );
            if (newName != null && newName.isNotEmpty && speakerId != null) {
              provider.renameSpeaker(meetingId, speakerId, newName);
            }
          },
          child: CircleAvatar(
            radius: 14,
            backgroundColor: context.appPrimary.withValues(alpha: 0.15),
            child: Text(
              initials.isNotEmpty ? initials : '?',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: context.appPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            displayName,
            style: GoogleFonts.manrope(
              color: context.appTextSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          _formatTime(segment.start),
          style: GoogleFonts.manrope(
            color: context.appTextTertiary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAudioPlayer(
    BuildContext context,
    Meeting live,
    MeetingProvider provider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPlayingThis = provider.currentlyPlayingMeeting?.id == live.id;
    final isPlaying = isPlayingThis && provider.isPlaying;
    final maxPosStr = isPlayingThis
        ? _formatDuration(provider.totalDuration)
        : '00:00';

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10_rounded),
                color: context.appPrimary,
                iconSize: 28,
                onPressed: () {
                  if (isPlayingThis) {
                    final newPos =
                        provider.playbackPosition - const Duration(seconds: 10);
                    provider.seek(
                      newPos < Duration.zero ? Duration.zero : newPos,
                    );
                  }
                },
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () {
                  provider.playMeeting(live);
                },
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: context.appPrimary,
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(Icons.forward_10_rounded),
                color: context.appPrimary,
                iconSize: 28,
                onPressed: () {
                  if (isPlayingThis) {
                    final newPos =
                        provider.playbackPosition + const Duration(seconds: 10);
                    provider.seek(
                      newPos > provider.totalDuration
                          ? provider.totalDuration
                          : newPos,
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Only the scrubber tracks the playhead, so a position tick repaints
          // this Row rather than the whole screen.
          ValueListenableBuilder<Duration>(
            valueListenable: provider.position,
            builder: (context, playhead, _) {
              final total = provider.totalDuration.inMilliseconds;
              var progress = 0.0;
              var currentPos = Duration.zero;

              if (isPlayingThis && total > 0) {
                if (_dragProgress != null) {
                  progress = _dragProgress!;
                  currentPos = Duration(
                    milliseconds: (_dragProgress! * total).toInt(),
                  );
                } else {
                  progress = playhead.inMilliseconds / total;
                  currentPos = playhead;
                }
              }

              return Row(
                children: [
                  Text(
                    isPlayingThis ? _formatDuration(currentPos) : '00:00',
                    style: GoogleFonts.manrope(
                      color: context.appTextTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 0,
                        ), // No thumb
                        overlayShape: SliderComponentShape.noOverlay,
                        activeTrackColor: context.appPrimary,
                        inactiveTrackColor: context.appSeparator,
                      ),
                      child: Slider(
                        value: progress.clamp(0.0, 1.0),
                        onChanged: (v) {
                          if (isPlayingThis) {
                            setState(() {
                              _dragProgress = v;
                            });
                          }
                        },
                        onChangeEnd: (v) {
                          setState(() {
                            _dragProgress = null;
                          });
                          if (isPlayingThis) {
                            provider.seek(
                              Duration(milliseconds: (v * total).toInt()),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    maxPosStr,
                    style: GoogleFonts.manrope(
                      color: context.appTextTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  // Dialogs from previous implementation remain identical
  Future<String?> _showRenameDialog(
    BuildContext context,
    String currentTitle,
  ) async {
    final controller = TextEditingController(text: currentTitle);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Rename',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.manrope(color: context.appTextPrimary),
          decoration: InputDecoration(
            hintText: 'Enter title',
            hintStyle: GoogleFonts.manrope(color: context.appTextTertiary),
            filled: true,
            fillColor: context.appSurfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.manrope()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(
              'Save',
              style: GoogleFonts.manrope(
                color: context.appPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirm(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Meeting?',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This action cannot be undone.',
          style: GoogleFonts.manrope(color: context.appTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.manrope()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              'Delete',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoveToFolderDialog(
    BuildContext context,
    MeetingProvider provider,
    Meeting meeting,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Move to Folder',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: Text(
                  'None (Remove from folder)',
                  style: GoogleFonts.manrope(),
                ),
                onTap: () {
                  provider.moveMeetingToFolder(meeting.id, null);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ...provider.folders.map(
                (folder) => ListTile(
                  leading: Icon(
                    Icons.folder_rounded,
                    color: Color(folder.colorValue),
                  ),
                  title: Text(folder.name, style: GoogleFonts.manrope()),
                  onTap: () {
                    provider.moveMeetingToFolder(meeting.id, folder.id);
                    Navigator.pop(context);
                  },
                ),
              ),
              if (provider.folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No folders created yet.',
                    style: GoogleFonts.manrope(color: context.appTextTertiary),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showCreateFolderDialog(context, provider);
            },
            child: Text(
              'New Folder',
              style: GoogleFonts.manrope(color: context.appPrimary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.manrope()),
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context, MeetingProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'New Folder',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.manrope(color: context.appTextPrimary),
          decoration: InputDecoration(
            hintText: 'Folder Name',
            hintStyle: GoogleFonts.manrope(color: context.appTextTertiary),
            filled: true,
            fillColor: context.appSurfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.manrope()),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.createFolder(
                  controller.text,
                  context.appPrimary.toARGB32(),
                );
                Navigator.pop(context);
              }
            },
            child: Text(
              'Create',
              style: GoogleFonts.manrope(
                color: context.appPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showRenameSpeakerDialog(
    BuildContext context,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Rename Speaker',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.manrope(color: context.appTextPrimary),
          decoration: InputDecoration(
            hintText: 'Enter name',
            hintStyle: GoogleFonts.manrope(color: context.appTextTertiary),
            filled: true,
            fillColor: context.appSurfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.manrope()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(
              'Save',
              style: GoogleFonts.manrope(
                color: context.appPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The user's free-text note for a recording. Always editable; there's no save
/// button -- it persists when the field loses focus and when the screen closes,
/// which matches how the rest of Scribe treats a note as just part of the
/// meeting rather than a separate document.
class _NotesCard extends StatefulWidget {
  const _NotesCard({required this.meeting});

  final Meeting meeting;

  @override
  State<_NotesCard> createState() => _NotesCardState();
}

class _NotesCardState extends State<_NotesCard> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  /// Captured in didChangeDependencies so dispose can persist without touching
  /// an inherited widget after the element is defunct.
  MeetingProvider? _provider;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.meeting.notes ?? '');
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _save();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<MeetingProvider>();
  }

  void _save() => _provider?.updateNotes(widget.meeting.id, _controller.text);

  @override
  void dispose() {
    _save();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.appShadowSubtle,
        border: Border.all(
          color: context.appSeparator.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                color: context.appTextPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('My Notes', style: context.sectionTitle),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: null,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: GoogleFonts.manrope(
              color: context.appTextPrimary,
              fontSize: 15,
              height: 1.5,
            ),
            decoration: InputDecoration(
              isCollapsed: true,
              hintText: 'Add your own notes…',
              hintStyle: GoogleFonts.manrope(
                color: context.appTextSecondary.withValues(alpha: 0.5),
                fontSize: 15,
              ),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingCard extends StatelessWidget {
  final MeetingProvider provider;
  const _ProcessingCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final label = provider.processingState == ProcessingState.summarizing
        ? 'Generating AI summary…'
        : 'Transcribing audio…';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appPrimary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: context.appPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final foreground = disabled
        ? context.appTextTertiary
        : selected
        ? Colors.white
        : context.appTextSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? context.appPrimary : context.appSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? context.appPrimary : context.appSeparator,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.manrope(
                color: foreground,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tappable action item. Ticking it strikes the text through and fades it,
/// so a finished list still reads as a record of what was agreed.
class _ActionItemRow extends StatelessWidget {
  const _ActionItemRow({
    required this.text,
    required this.completed,
    required this.onToggle,
  });

  final String text;
  final bool completed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0, right: 12.0),
              child: Icon(
                completed
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: completed
                    ? context.appPrimary
                    : context.appPrimary.withValues(alpha: 0.5),
                size: 20,
              ),
            ),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: GoogleFonts.manrope(
                  color: completed
                      ? context.appTextTertiary
                      : context.appTextSecondary,
                  fontSize: 15,
                  height: 1.5,
                  decoration: completed
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: context.appTextTertiary,
                ),
                child: Text(text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
