import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/meeting.dart';
import '../providers/meeting_provider.dart';
import '../widgets/synced_transcript.dart';
import 'detail_screen.dart';

class PlayerScreen extends StatefulWidget {
  final Meeting meeting;

  const PlayerScreen({super.key, required this.meeting});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  double? _dragProgress;
  bool _showLyrics = false;

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  /// Tapping a transcript line on a meeting that isn't loaded in the player
  /// should start it there. Guarded on the id because [MeetingProvider.playMeeting]
  /// toggles pause when handed the meeting already playing.
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

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingProvider>(
      builder: (context, provider, _) {
        // Segments land asynchronously once transcription finishes, so read the
        // live copy rather than the one this screen was constructed with.
        final live = provider.allMeetings.firstWhere(
          (m) => m.id == widget.meeting.id,
          orElse: () => widget.meeting,
        );
        final hasSegments = live.segments.isNotEmpty;

        final isCurrent = provider.currentlyPlayingId == widget.meeting.id;
        final dur = isCurrent ? provider.totalDuration : Duration.zero;
        final isPlaying = isCurrent && provider.isPlaying;

        // Read (rather than watch) the playhead: the skip buttons need its
        // current value, but only the scrubber below should repaint on a tick.
        Duration seekBase() =>
            isCurrent ? provider.playbackPosition : Duration.zero;

        return Scaffold(
          backgroundColor: context.appBackground,
          body: SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 32,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      PopupMenuButton<String>(
                        color: context.appSurface,
                        surfaceTintColor: Colors.transparent,
                        position: PopupMenuPosition.under,
                        offset: const Offset(0, 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        icon: const Icon(Icons.more_horiz_rounded),
                        onSelected: (value) async {
                          if (value == 'rename') {
                            final newTitle = await _showRenameDialog(
                              context,
                              widget.meeting.title,
                            );
                            if (newTitle != null) {
                              provider.renameMeeting(
                                widget.meeting.id,
                                newTitle,
                              );
                            }
                          } else if (value == 'delete') {
                            final confirm = await _showDeleteConfirm(context);
                            if (confirm == true) {
                              provider.deleteMeeting(widget.meeting.id);
                              if (context.mounted) Navigator.pop(context);
                            }
                          } else if (value == 'move') {
                            _showMoveToFolderDialog(
                              context,
                              provider,
                              widget.meeting,
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Text('Rename'),
                          ),
                          const PopupMenuItem(
                            value: 'move',
                            child: Text('Move to Folder'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        if (_showLyrics)
                          Expanded(
                            child: SyncedTranscript(
                              segments: live.segments,
                              position: provider.position,
                              density: TranscriptDensity.fullScreen,
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              onSeek: (to) => _seekWithin(provider, live, to),
                            ),
                          )
                        else ...[
                          const Spacer(flex: 2),
                          // Artwork
                          Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  context.appPrimary,
                                  Color.lerp(
                                    context.appPrimary,
                                    Colors.white,
                                    0.18,
                                  )!,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: context.appPrimary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 40,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.graphic_eq_rounded,
                                color: Colors.white,
                                size: 72,
                              ),
                            ),
                          ),
                          const Spacer(flex: 2),
                        ],

                        // Title
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.meeting.title,
                                style: context.sheetTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.meeting.team,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: context.appTextTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Scrubber. Subscribes to the playhead on its own so a
                        // position tick doesn't repaint the transcript above it.
                        ValueListenableBuilder<Duration>(
                          valueListenable: provider.position,
                          builder: (context, playhead, _) {
                            var currentPos = isCurrent
                                ? playhead
                                : Duration.zero;
                            var progress = 0.0;

                            if (dur.inMilliseconds > 0) {
                              if (_dragProgress != null) {
                                progress = _dragProgress!;
                                currentPos = Duration(
                                  milliseconds:
                                      (_dragProgress! * dur.inMilliseconds)
                                          .toInt(),
                                );
                              } else {
                                progress =
                                    (currentPos.inMilliseconds /
                                            dur.inMilliseconds)
                                        .clamp(0.0, 1.0);
                              }
                            }

                            return Column(
                              children: [
                                SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                    ),
                                    activeTrackColor: context.appPrimary,
                                    inactiveTrackColor: context.appSeparator,
                                    thumbColor: context.appPrimary,
                                    overlayShape:
                                        SliderComponentShape.noOverlay,
                                  ),
                                  child: Slider(
                                    value: progress,
                                    onChanged: (val) {
                                      if (dur.inMilliseconds > 0) {
                                        setState(() {
                                          _dragProgress = val;
                                        });
                                      }
                                    },
                                    onChangeEnd: (val) {
                                      setState(() {
                                        _dragProgress = null;
                                      });
                                      if (dur.inMilliseconds > 0) {
                                        provider.seek(
                                          Duration(
                                            milliseconds:
                                                (val * dur.inMilliseconds)
                                                    .toInt(),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(currentPos),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.appTextTertiary,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(dur),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.appTextTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        SizedBox(height: 28),

                        // Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: Icon(Icons.replay_10_rounded, size: 32),
                              color: context.appTextPrimary,
                              onPressed: () {
                                provider.seek(
                                  seekBase() - const Duration(seconds: 10),
                                );
                              },
                            ),
                            GestureDetector(
                              onTap: () => provider.playMeeting(widget.meeting),
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: context.appPrimary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 36,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.forward_30_rounded, size: 32),
                              color: context.appTextPrimary,
                              onPressed: () {
                                provider.seek(
                                  seekBase() + const Duration(seconds: 30),
                                );
                              },
                            ),
                          ],
                        ),
                        // The transcript already takes the free space when it's
                        // showing, so there is none left to distribute here.
                        if (_showLyrics)
                          const SizedBox(height: 24)
                        else
                          const Spacer(flex: 2),

                        // Bottom actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            PopupMenuButton<double>(
                              color: context.appSurface,
                              surfaceTintColor: Colors.transparent,
                              position: PopupMenuPosition.under,
                              offset: const Offset(0, 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              icon: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(Icons.speed_rounded),
                                  if (provider.playbackSpeed != 1.0)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: context.appPrimary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${provider.playbackSpeed.toStringAsFixed(1)}x',
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              onSelected: (speed) =>
                                  provider.setPlaybackSpeed(speed),
                              itemBuilder: (context) =>
                                  [0.5, 0.8, 1.0, 1.2, 1.5, 2.0]
                                      .map(
                                        (s) => PopupMenuItem(
                                          value: s,
                                          child: Text('${s}x'),
                                        ),
                                      )
                                      .toList(),
                            ),
                            IconButton(
                              icon: Icon(
                                _showLyrics
                                    ? Icons.subtitles_rounded
                                    : Icons.subtitles_outlined,
                              ),
                              // Nothing to follow along with until the recording
                              // has been transcribed into timed segments.
                              color: hasSegments
                                  ? (_showLyrics
                                        ? context.appPrimary
                                        : context.appTextSecondary)
                                  : context.appTextTertiary,
                              tooltip: hasSegments
                                  ? 'Follow transcript'
                                  : 'No transcript yet',
                              onPressed: hasSegments
                                  ? () => setState(
                                      () => _showLyrics = !_showLyrics,
                                    )
                                  : null,
                            ),
                            IconButton(
                              icon: Icon(
                                live.isFavorite
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_outline_rounded,
                              ),
                              color: live.isFavorite
                                  ? context.appPrimary
                                  : context.appTextSecondary,
                              onPressed: () =>
                                  provider.toggleFavorite(live.id),
                            ),
                            IconButton(
                              icon: Icon(Icons.text_snippet_outlined),
                              color: context.appPrimary,
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DetailScreen(meeting: widget.meeting),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showRenameDialog(
    BuildContext context,
    String currentTitle,
  ) async {
    final controller = TextEditingController(text: currentTitle);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rename Meeting'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'New Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirm(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Meeting'),
        content: Text('Are you sure you want to delete this recording?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
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
    final live = provider.allMeetings.firstWhere(
      (m) => m.id == meeting.id,
      orElse: () => meeting,
    );
    final selected = <String>{...live.folderIds};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Move to Folder'),
          content: SizedBox(
            width: double.maxFinite,
            child: provider.folders.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No folders created yet.',
                      style: TextStyle(color: context.appTextTertiary),
                    ),
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: provider.folders.map((folder) {
                          return CheckboxListTile(
                            value: selected.contains(folder.id),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                selected.add(folder.id);
                              } else {
                                selected.remove(folder.id);
                              }
                            }),
                            activeColor: context.appPrimary,
                            controlAffinity: ListTileControlAffinity.leading,
                            secondary: Icon(
                              Icons.folder_rounded,
                              color: Color(folder.colorValue),
                            ),
                            title: Text(folder.name),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Keep this dialog open; create the folder on top of it, then
                // tick it so the user can keep choosing folders.
                final newId = await _showCreateFolderDialog(context, provider);
                if (newId != null) setState(() => selected.add(newId));
              },
              child: Text('New Folder'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                provider.setMeetingFolders(meeting.id, selected.toList());
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows the create-folder prompt and returns the new folder's id, or null if
  /// the user cancelled.
  Future<String?> _showCreateFolderDialog(
    BuildContext context,
    MeetingProvider provider,
  ) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Folder Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final id = await provider.createFolder(
                  controller.text.trim(),
                  context.appPrimary.toARGB32(),
                );
                if (context.mounted) Navigator.pop(context, id);
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }
}
