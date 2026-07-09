import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/meeting_provider.dart';
import '../models/meeting.dart';

class DetailScreen extends StatefulWidget {
  final Meeting meeting;
  const DetailScreen({super.key, required this.meeting});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double? _dragProgress;

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
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      live.title,
                      style: GoogleFonts.manrope(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                        letterSpacing: -0.8,
                        height: 1.1,
                      ),
                    ),
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
                    labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 13),
                    unselectedLabelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 13),
                    dividerColor: Colors.transparent, // Remove default underline
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

  PreferredSizeWidget _buildAppBar(BuildContext context, Meeting live, MeetingProvider provider) {
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
          child: Icon(Icons.arrow_back_ios_new_rounded, color: context.appTextPrimary, size: 16),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('Meeting Details', style: GoogleFonts.manrope(color: context.appTextPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      actions: [
        PopupMenuButton<String>(
          color: context.appSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          icon: Icon(Icons.edit_outlined, color: context.appTextPrimary, size: 24),
          onSelected: (value) async {
            if (value == 'rename') {
              final newTitle = await _showRenameDialog(context, live.title);
              if (newTitle != null) provider.renameMeeting(live.id, newTitle);
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
              value: 'delete',
              child: Text('Delete', style: GoogleFonts.manrope(color: Colors.red)),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSummaryView(BuildContext context, Meeting live, MeetingProvider provider) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        if (live.summary != null && live.summary!.isNotEmpty)
          _buildSummaryCard(
            context,
            'Smart Summary',
            Icons.lightbulb,
            live.summary!,
          ),
        if (live.actionItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildActionItemsCard(context, live.actionItems),
        ],
        if (live.highlights.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildHighlightsCard(context, live.highlights),
        ],
        if ((live.summary == null || live.summary!.isEmpty) && live.actionItems.isEmpty)
          Center(
            child: Text(
              provider.currentProcessingId == live.id
                  ? 'Generating summary…'
                  : 'No summary available.',
              style: GoogleFonts.manrope(color: context.appTextSecondary),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.appShadowSubtle,
        border: Border.all(color: context.appSeparator.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.appPrimary, size: 20),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.manrope(color: context.appTextPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
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
                    child: Container(width: 6, height: 6, decoration: BoxDecoration(color: context.appPrimary, shape: BoxShape.circle)),
                  ),
                  Expanded(child: Text(content, style: GoogleFonts.manrope(color: context.appTextSecondary, fontSize: 15, height: 1.5))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionItemsCard(BuildContext context, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.appShadowSubtle,
        border: Border.all(color: context.appSeparator.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: context.appTextPrimary, size: 20),
              const SizedBox(width: 8),
              Text('Action Items', style: GoogleFonts.manrope(color: context.appTextPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0, right: 12.0),
                      child: Icon(Icons.check_box_outline_blank_rounded, color: context.appPrimary.withValues(alpha: 0.5), size: 20),
                    ),
                    Expanded(
                        child: Text(item, style: GoogleFonts.manrope(color: context.appTextSecondary, fontSize: 15, height: 1.5))),
                  ],
                ),
              )),
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
        border: Border.all(color: context.appSeparator.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_outline_rounded, color: context.appTextPrimary, size: 20),
              const SizedBox(width: 8),
              Text('Highlights', style: GoogleFonts.manrope(color: context.appTextPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, right: 12.0),
                      child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                    ),
                    Expanded(
                        child: Text(item, style: GoogleFonts.manrope(color: context.appTextSecondary, fontSize: 15, height: 1.5))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTranscriptView(BuildContext context, Meeting live, MeetingProvider provider) {
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
                border: Border.all(color: context.appSeparator.withValues(alpha: 0.5), width: 0.5),
              ),
              child: Text(live.transcript!, style: GoogleFonts.manrope(color: context.appTextPrimary, fontSize: 15, height: 1.6)),
            )
          ]
        );
      }
      return Center(
        child: Text(
          provider.currentProcessingId == live.id ? 'Transcribing…' : 'No transcript available.',
          style: GoogleFonts.manrope(color: context.appTextSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: live.segments.length,
      itemBuilder: (context, index) {
        final seg = live.segments[index];
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return _buildTranscriptLine(context, live.id, seg, live.speakerMapping, isDark, provider);
      },
    );
  }

  String _formatTime(double seconds) {
    final m = seconds ~/ 60;
    final s = seconds.toInt() % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildTranscriptLine(
      BuildContext context, String meetingId, MeetingSegment segment, Map<String, String> speakerMapping, bool isDark, MeetingProvider provider) {
    final speakerId = segment.speaker;
    final displayName = speakerId != null ? (speakerMapping[speakerId] ?? speakerId) : 'Unknown';
    // Generate initials for avatar
    final initials = displayName.split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                   final newName = await _showRenameSpeakerDialog(context, displayName);
                    if (newName != null && newName.isNotEmpty && speakerId != null) {
                      provider.renameSpeaker(meetingId, speakerId, newName);
                    }
                },
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: context.appPrimary.withValues(alpha: 0.15),
                  child: Text(
                    initials.isNotEmpty ? initials : '?',
                    style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.bold, color: context.appPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayName,
                  style: GoogleFonts.manrope(color: context.appTextSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _formatTime(segment.start),
                style: GoogleFonts.manrope(color: context.appTextTertiary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            segment.text,
            style: GoogleFonts.manrope(color: context.appTextPrimary, fontSize: 16, height: 1.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer(BuildContext context, Meeting live, MeetingProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPlayingThis = provider.currentlyPlayingMeeting?.id == live.id;
    final isPlaying = isPlayingThis && provider.isPlaying;
    
    // We will just use the exact logic of MiniPlayer but restyle it to match Granola
    Duration currentPos = Duration.zero;
    double progress = 0.0;
    String currentPosStr = '00:00';
    String maxPosStr = '00:00';

    if (isPlayingThis) {
      if (provider.totalDuration.inMilliseconds > 0) {
        if (_dragProgress != null) {
          progress = _dragProgress!;
          currentPos = Duration(milliseconds: (_dragProgress! * provider.totalDuration.inMilliseconds).toInt());
        } else {
          progress = provider.playbackPosition.inMilliseconds / provider.totalDuration.inMilliseconds;
          currentPos = provider.playbackPosition;
        }
      }
      currentPosStr = _formatDuration(currentPos);
      maxPosStr = _formatDuration(provider.totalDuration);
    } else {
      progress = 0.0;
      currentPosStr = '00:00';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
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
                    final newPos = provider.playbackPosition - const Duration(seconds: 10);
                    provider.seek(newPos < Duration.zero ? Duration.zero : newPos);
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
                    final newPos = provider.playbackPosition + const Duration(seconds: 10);
                    provider.seek(newPos > provider.totalDuration ? provider.totalDuration : newPos);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(currentPosStr, style: GoogleFonts.manrope(color: context.appTextTertiary, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0), // No thumb
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
                        final ms = (v * provider.totalDuration.inMilliseconds).toInt();
                        provider.seek(Duration(milliseconds: ms));
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(maxPosStr, style: GoogleFonts.manrope(color: context.appTextTertiary, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
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
  Future<String?> _showRenameDialog(BuildContext context, String currentTitle) async {
    final controller = TextEditingController(text: currentTitle);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.manrope())),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Save', style: GoogleFonts.manrope(color: context.appPrimary, fontWeight: FontWeight.w600)),
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
        title: Text('Delete Meeting?', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Text('This action cannot be undone.', style: GoogleFonts.manrope(color: context.appTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.manrope())),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showMoveToFolderDialog(BuildContext context, MeetingProvider provider, Meeting meeting) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Move to Folder', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: Text('None (Remove from folder)', style: GoogleFonts.manrope()),
                onTap: () { provider.moveMeetingToFolder(meeting.id, null); Navigator.pop(context); },
              ),
              const Divider(),
              ...provider.folders.map((folder) => ListTile(
                leading: Icon(Icons.folder_rounded, color: Color(folder.colorValue)),
                title: Text(folder.name, style: GoogleFonts.manrope()),
                onTap: () { provider.moveMeetingToFolder(meeting.id, folder.id); Navigator.pop(context); },
              )),
              if (provider.folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No folders created yet.', style: GoogleFonts.manrope(color: context.appTextTertiary)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); _showCreateFolderDialog(context, provider); },
            child: Text('New Folder', style: GoogleFonts.manrope(color: context.appPrimary)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: GoogleFonts.manrope())),
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
        title: Text('New Folder', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.manrope(color: context.appTextPrimary),
          decoration: InputDecoration(
            hintText: 'Folder Name',
            hintStyle: GoogleFonts.manrope(color: context.appTextTertiary),
            filled: true,
            fillColor: context.appSurfaceVariant,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.manrope())),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.createFolder(controller.text, context.appPrimary.toARGB32());
                Navigator.pop(context);
              }
            },
            child: Text('Create', style: GoogleFonts.manrope(color: context.appPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<String?> _showRenameSpeakerDialog(BuildContext context, String currentName) async {
    final controller = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename Speaker', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.manrope(color: context.appTextPrimary),
          decoration: InputDecoration(
            hintText: 'Enter name',
            hintStyle: GoogleFonts.manrope(color: context.appTextTertiary),
            filled: true,
            fillColor: context.appSurfaceVariant,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.manrope())),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Save', style: GoogleFonts.manrope(color: context.appPrimary, fontWeight: FontWeight.w600)),
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
            child: CircularProgressIndicator(strokeWidth: 2.5, color: context.appPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: context.appTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
