import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/meeting.dart';
import '../providers/meeting_provider.dart';
import 'detail_screen.dart';

class PlayerScreen extends StatefulWidget {
  final Meeting meeting;

  const PlayerScreen({super.key, required this.meeting});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  double? _dragProgress;

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingProvider>(
      builder: (context, provider, _) {
        final isCurrent = provider.currentlyPlayingId == widget.meeting.id;
        final dur = isCurrent ? provider.totalDuration : Duration.zero;
        
        // If we are dragging, show the fake un-laggy drag position. Otherwise, show real position.
        Duration currentPos = isCurrent ? provider.playbackPosition : Duration.zero;
        double progress = 0.0;
        
        if (dur.inMilliseconds > 0) {
          if (_dragProgress != null) {
            progress = _dragProgress!;
            currentPos = Duration(milliseconds: (_dragProgress! * dur.inMilliseconds).toInt());
          } else {
            progress = (currentPos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
          }
        }
        
        final isPlaying = isCurrent && provider.isPlaying;

        return Scaffold(
          backgroundColor: context.appBackground,
          body: SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                        onPressed: () => Navigator.pop(context),
                      ),
                      PopupMenuButton<String>(
                        color: context.appSurface,
                        surfaceTintColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        icon: const Icon(Icons.more_horiz_rounded),
                        onSelected: (value) async {
                          if (value == 'rename') {
                            final newTitle = await _showRenameDialog(context, widget.meeting.title);
                            if (newTitle != null) {
                              provider.renameMeeting(widget.meeting.id, newTitle);
                            }
                          } else if (value == 'delete') {
                            final confirm = await _showDeleteConfirm(context);
                            if (confirm == true) {
                              provider.deleteMeeting(widget.meeting.id);
                              if (context.mounted) Navigator.pop(context);
                            }
                          } else if (value == 'move') {
                            _showMoveToFolderDialog(context, provider, widget.meeting);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'rename', child: Text('Rename')),
                          const PopupMenuItem(value: 'move', child: Text('Move to Folder')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
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
                        const Spacer(flex: 2),
                        // Artwork
                        Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A8C7E), Color(0xFF2DB5A5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: context.appPrimary.withValues(alpha: 0.3),
                                blurRadius: 40,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 72),
                          ),
                        ),
                        const Spacer(flex: 2),

                        // Title
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.meeting.title,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
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

                        // Scrubber
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            activeTrackColor: context.appTextPrimary,
                            inactiveTrackColor: context.appSeparator,
                            thumbColor: context.appTextPrimary,
                            overlayShape: SliderComponentShape.noOverlay,
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
                                provider.seek(Duration(milliseconds: (val * dur.inMilliseconds).toInt()));
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(currentPos),
                              style: TextStyle(fontSize: 12, color: context.appTextTertiary),
                            ),
                            Text(
                              _formatDuration(dur),
                              style: TextStyle(fontSize: 12, color: context.appTextTertiary),
                            ),
                          ],
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
                                provider.seek(currentPos - const Duration(seconds: 10));
                              },
                            ),
                            GestureDetector(
                              onTap: () => provider.playMeeting(widget.meeting),
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: context.appTextPrimary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  size: 36,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.forward_30_rounded, size: 32),
                              color: context.appTextPrimary,
                              onPressed: () {
                                provider.seek(currentPos + const Duration(seconds: 30));
                              },
                            ),
                          ],
                        ),
                        Spacer(flex: 2),

                        // Bottom actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            PopupMenuButton<double>(
                              color: context.appSurface,
                              surfaceTintColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                        decoration: BoxDecoration(color: context.appPrimary, shape: BoxShape.circle),
                                        child: Text(
                                          '${provider.playbackSpeed.toStringAsFixed(1)}x',
                                          style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              onSelected: (speed) => provider.setPlaybackSpeed(speed),
                              itemBuilder: (context) => [0.5, 0.8, 1.0, 1.2, 1.5, 2.0].map((s) => PopupMenuItem(
                                value: s,
                                child: Text('${s}x'),
                              )).toList(),
                            ),
                            IconButton(
                              icon: Icon(
                                widget.meeting.isFavorite ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                              ),
                              color: widget.meeting.isFavorite ? context.appPrimary : context.appTextSecondary,
                              onPressed: () => provider.toggleFavorite(widget.meeting.id),
                            ),
                            IconButton(
                              icon: Icon(Icons.share_outlined),
                              color: context.appPrimary,
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: Icon(Icons.text_snippet_outlined),
                              color: context.appPrimary,
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => DetailScreen(meeting: widget.meeting)),
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

  Future<String?> _showRenameDialog(BuildContext context, String currentTitle) async {
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text('Save')),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _showMoveToFolderDialog(BuildContext context, MeetingProvider provider, Meeting meeting) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Move to Folder'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.folder_off_outlined),
                title: Text('None (Remove from folder)'),
                onTap: () {
                  provider.moveMeetingToFolder(meeting.id, null);
                  Navigator.pop(context);
                },
              ),
              Divider(),
              ...provider.folders.map((folder) => ListTile(
                leading: Icon(Icons.folder_rounded, color: Color(folder.colorValue)),
                title: Text(folder.name),
                onTap: () {
                  provider.moveMeetingToFolder(meeting.id, folder.id);
                  Navigator.pop(context);
                },
              )),
              if (provider.folders.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No folders created yet.', style: TextStyle(color: context.appTextTertiary)),
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
            child: Text('New Folder'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
        ],
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context, MeetingProvider provider) {
    final controller = TextEditingController();
    showDialog(
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.createFolder(controller.text, context.appPrimary.toARGB32());
                Navigator.pop(context);
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }
}
