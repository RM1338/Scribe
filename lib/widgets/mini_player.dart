import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/meeting.dart';
import '../providers/meeting_provider.dart';
import 'package:provider/provider.dart';

class MiniPlayer extends StatelessWidget {
  final Meeting meeting;
  final VoidCallback? onTap;

  const MiniPlayer({super.key, required this.meeting, this.onTap});

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingProvider>(
      builder: (context, provider, _) {
        final isCurrent = provider.currentlyPlayingId == meeting.id;
        final isPlaying = provider.isPlaying && isCurrent;
        final dur = isCurrent ? provider.totalDuration : Duration.zero;

        return ValueListenableBuilder<Duration>(
          valueListenable: provider.position,
          builder: (context, playhead, _) {
            final pos = isCurrent ? playhead : Duration.zero;
            return _build(
              context,
              provider,
              isPlaying: isPlaying,
              pos: pos,
              dur: dur,
            );
          },
        );
      },
    );
  }

  Widget _build(
    BuildContext context,
    MeetingProvider provider, {
    required bool isPlaying,
    required Duration pos,
    required Duration dur,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Artwork
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A8C7E), Color(0xFF2DB5A5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 12),
                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meeting.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${meeting.team} • ${_formatDuration(pos)} / ${_formatDuration(dur)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Controls
                  IconButton(
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 28,
                    ),
                    color: context.appTextPrimary,
                    onPressed: () => provider.playMeeting(meeting),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.forward_30_rounded, size: 22),
                    color: context.appTextSecondary,
                    onPressed: () {
                      provider.seek(pos + const Duration(seconds: 30));
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
              if (dur.inMilliseconds > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 56),
                  child: LinearProgressIndicator(
                    value: (pos.inMilliseconds / dur.inMilliseconds).clamp(
                      0.0,
                      1.0,
                    ),
                    backgroundColor: context.appSeparator,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.appPrimary,
                    ),
                    minHeight: 2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
