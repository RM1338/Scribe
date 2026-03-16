import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/meeting_provider.dart';
import '../navigation/app_shell.dart';
import 'detail_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> with SingleTickerProviderStateMixin {
  String? _pendingTitle;
  late AnimationController _pulseController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Setup the pulsing animation for the recording indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Listen to notifications from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<MeetingProvider>(context, listen: false);
      provider.notificationStream.listen((message) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
              backgroundColor: context.appPrimary,
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      final h = d.inHours.toString().padLeft(2, '0');
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    } else {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }
  }

  Future<void> _handleStop(BuildContext context, MeetingProvider provider) async {
    final path = await provider.stopRecording();
    if (path != null) {
      final meeting = await provider.createMeetingFromRecording(path, title: _pendingTitle);
      setState(() => _pendingTitle = null);
      if (context.mounted) {
        // Switch back to library tab and push detail screen on top
        AppShell.switchToTab(0);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DetailScreen(meeting: meeting)),
        );
      }
    }
  }

  String _monthName(int month) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return m[month - 1];
  }

  Future<String?> _showNamingDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: 'Meeting ${_monthName(DateTime.now().month)} ${DateTime.now().day}',
    );
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Name your recording',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: context.appTextPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Give your meeting a name to get started.',
              style: GoogleFonts.manrope(fontSize: 14, color: context.appTextSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: GoogleFonts.manrope(color: context.appTextPrimary),
              decoration: InputDecoration(
                hintText: 'Meeting Title',
                hintStyle: GoogleFonts.manrope(color: context.appTextTertiary),
                filled: true,
                fillColor: context.appSurfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.appPrimary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.manrope(color: context.appTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Start', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingProvider>(
      builder: (context, provider, _) {
        final isRecording = provider.recordingState == RecordingState.recording;
        final isPaused = provider.recordingState == RecordingState.paused;
        final isIdle = provider.recordingState == RecordingState.idle;
        
        final bool isDark = Theme.of(context).brightness == Brightness.dark;

        // Granola specified hardcoded mockup colors for overrides where appropriate
        // although we map most to appTheme where it fits perfectly.
        final Color surfaceColor = context.appSurface;
        final Color textPrimary = context.appTextPrimary;
        final Color textSecondary = context.appTextSecondary;
        final Color scribeTeal = context.appPrimary;
        const Color stopRed = Color(0xFFE85D4A);

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button (resembling settings/back in mockup)
                InkWell(
                  onTap: () => AppShell.switchToTab(0),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 16),
                  ),
                ),
                
                // Status Pill / Title
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isIdle)
                      FadeTransition(
                        opacity: isRecording ? _pulseController : const AlwaysStoppedAnimation(1.0),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isPaused ? Colors.orange : scribeTeal,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    if (!isIdle) const SizedBox(width: 12),
                    Column(
                      children: [
                        Text(
                          _pendingTitle ?? 'New Recording',
                          style: GoogleFonts.manrope(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        if (!isIdle) ... [
                          const SizedBox(height: 2),
                          Text(
                            isPaused ? 'PAUSED' : 'LIVE RECORDING',
                            style: GoogleFonts.manrope(color: textSecondary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1),
                          )
                        ]
                      ],
                    ),
                  ],
                ),

                // Settings Button (matching mockup)
                InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.settings_outlined, color: scribeTeal, size: 20),
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              const SizedBox(height: 24),
              
              // 1. Large Minimalist Timer
              Text(
                _formatDuration(provider.recordingDuration),
                style: GoogleFonts.manrope(
                  fontSize: 80,
                  fontWeight: FontWeight.w200,
                  color: textPrimary,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ELAPSED TIME',
                style: GoogleFonts.manrope(color: scribeTeal.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
              ),

              const SizedBox(height: 24),

              // 2. Live Transcription Container
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: context.appSeparator.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: isIdle
                      ? Center(
                          child: Text(
                            "Ready when you are.\nTap record to begin.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(color: textSecondary, fontSize: 16, height: 1.5),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FadeTransition(
                                opacity: isRecording
                                    ? _pulseController
                                    : const AlwaysStoppedAnimation(1.0),
                                child: Icon(
                                  isPaused ? Icons.pause_circle_outline : Icons.graphic_eq_rounded,
                                  color: isPaused ? Colors.orange : scribeTeal,
                                  size: 48,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isPaused ? 'Recording paused' : 'Recording in progress…',
                                style: GoogleFonts.manrope(
                                  color: textSecondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Full transcription will run automatically\nwhen you stop recording.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  color: textSecondary.withValues(alpha: 0.6),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 24),

              // 3. Control Buttons
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Bookmark (Disabled if idle)
                     Opacity(
                       opacity: isIdle ? 0.3 : 1.0,
                       child: _buildSecondaryButton(Icons.bookmark_border_rounded, 'BOOKMARK', scribeTeal, isDark, () {}),
                     ),

                    // Main Action (Record if idle, Stop if active)
                    GestureDetector(
                      onTap: () async {
                        if (isIdle) {
                          final title = await _showNamingDialog(context);
                          if (title != null) {
                            setState(() => _pendingTitle = title);
                            provider.startRecording();
                          }
                        } else {
                          await _handleStop(context, provider);
                        }
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isIdle ? scribeTeal : stopRed,
                          shape: BoxShape.circle,
                          boxShadow: [
                             BoxShadow(
                                color: (isIdle ? scribeTeal : stopRed).withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                             )
                          ]
                        ),
                        child: Center(
                          child: Icon(
                            isIdle ? Icons.mic_rounded : Icons.stop_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),

                    // Pause Button
                    Opacity(
                       opacity: isIdle ? 0.3 : 1.0,
                       child: _buildSecondaryButton(
                         isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                         isPaused ? 'RESUME' : 'PAUSE',
                         scribeTeal,
                         isDark,
                         () {
                           if (!isIdle) {
                             if (isPaused) {
                               provider.resumeRecording();
                             } else {
                               provider.pauseRecording();
                             }
                           }
                         },
                       ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildSecondaryButton(IconData icon, String label, Color teal, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: teal.withValues(alpha: 0.2)),
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
            ),
            child: Icon(icon, color: teal, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.manrope(color: context.appTextPrimary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}
