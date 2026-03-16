import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_theme.dart';
import '../providers/meeting_provider.dart';
import '../navigation/app_shell.dart';
import 'detail_screen.dart';

class UploadProgressScreen extends StatefulWidget {
  final PlatformFile file;
  
  const UploadProgressScreen({super.key, required this.file});

  @override
  State<UploadProgressScreen> createState() => _UploadProgressScreenState();
}

class _UploadProgressScreenState extends State<UploadProgressScreen> {
  double _progress = 0.0;
  bool _isUploading = true;
  bool _isCancelled = false;
  late Stream<List<int>> _readStream;
  late IOSink _writeSink;
  int _totalBytes = 0;
  int _bytesTransferred = 0;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startUpload();
  }

  String _monthName(int month) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return m[month - 1];
  }

  Future<String?> _showNamingDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: 'Upload ${_monthName(DateTime.now().month)} ${DateTime.now().day}',
    );
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Name your upload',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: context.appTextPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Give your uploaded recording a name.',
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Done', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _processUploadedFile(String audioPath) async {
    if (_isCancelled || !mounted) return;
    
    // Get actual duration using AudioPlayer without playing it
    Duration? fileDuration;
    try {
      final player = AudioPlayer();
      await player.setSourceDeviceFile(audioPath);
      fileDuration = await player.getDuration();
      await player.dispose();
    } catch (_) {
      // Fallback if unable to determine duration
      fileDuration = Duration.zero;
    }

    if (!mounted) return;

    // Show naming dialog before saving
    final title = await _showNamingDialog(context) ?? 'My Upload';
    
    if (!mounted) return;
    
    final provider = context.read<MeetingProvider>();
    final meeting = await provider.createMeetingFromRecording(
      audioPath, 
      title: title,
      duration: fileDuration,
    );

    if (mounted) {
      // Navigate to the library detail view to show transcription in progress
      AppShell.switchToTab(0);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(meeting: meeting)),
      );
    }
  }

  Future<void> _startUpload() async {
    try {
      if (widget.file.path == null) {
        throw Exception("File path is null");
      }
      
      final sourceFile = File(widget.file.path!);
      if (!await sourceFile.exists()) {
        throw Exception("Source file does not exist");
      }

      _totalBytes = await sourceFile.length();
      _startTime = DateTime.now();

      final destDir = await getApplicationDocumentsDirectory();
      // Ensure unique name
      String destPath = p.join(destDir.path, p.basename(sourceFile.path));
      File destFile = File(destPath);
      int counter = 1;
      while (await destFile.exists()) {
        final filename = '${p.basenameWithoutExtension(sourceFile.path)}_$counter${p.extension(sourceFile.path)}';
        destPath = p.join(destDir.path, filename);
        destFile = File(destPath);
        counter++;
      }

      _readStream = sourceFile.openRead();
      _writeSink = destFile.openWrite();

      _readStream.listen(
        (chunk) {
          if (_isCancelled) return;
          
          _writeSink.add(chunk);
          _bytesTransferred += chunk.length;
          
          if (mounted) {
            setState(() {
              _progress = _bytesTransferred / _totalBytes;
            });
          }
        },
        onDone: () async {
          if (_isCancelled) return;
          await _writeSink.close();
          
          if (mounted) {
            setState(() {
              _isUploading = false;
              _progress = 1.0;
            });
            // Process the uploaded file
            await _processUploadedFile(destPath);
          }
        },
        onError: (e) {
          debugPrint("Upload error: $e");
          _cancelUpload();
        },
      );
    } catch (e) {
      debugPrint("Failed to start upload: $e");
    }
  }

  void _cancelUpload() {
    _isCancelled = true;
    try {
      _writeSink.close();
    } catch (_) {}
    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getEstimatedTimeLeft() {
    if (_startTime == null || _bytesTransferred == 0 || _totalBytes == 0) {
      return 'Calculating...';
    }
    
    final elapsedMs = DateTime.now().difference(_startTime!).inMilliseconds;
    if (elapsedMs == 0) return 'Calculating...';
    
    final bytesPerMs = _bytesTransferred / elapsedMs;
    final remainingBytes = _totalBytes - _bytesTransferred;
    final remainingMs = remainingBytes / bytesPerMs;
    
    final remainingSecs = (remainingMs / 1000).ceil();
    if (remainingSecs < 60) {
      return '${remainingSecs}s';
    }
    return '${(remainingSecs / 60).floor()}m ${remainingSecs % 60}s';
  }

  @override
  Widget build(BuildContext context) {
    // Detects whether the app is currently in Light or Dark mode
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // --- Scribe Design System: Light Theme (#F8F7F4) vs Dark Theme (#121212) ---
    final Color bgColor = context.appBackground;
    final Color cardColor = context.appSurface;
    final Color textPrimary = context.appTextPrimary;
    final Color textSecondary = context.appTextSecondary;
    final Color trackColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05);
    final Color cancelButtonBg = isDark ? const Color(0xFF1E1E1E) : Colors.black.withValues(alpha: 0.04);

    // Constant Accents
    final Color scribeTeal = context.appPrimary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 20),
              onPressed: () {
                _cancelUpload();
              },
            ),
          ),
        ),
        title: Text(
          'Upload Progress',
          style: GoogleFonts.manrope(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const Spacer(flex: 2),
            
            // 1. Central Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // File Icon with Brand Accent
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scribeTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.movie_outlined, color: scribeTeal, size: 36),
                  ),
                  const SizedBox(height: 24),
                  
                  // File Information
                  Text(
                    widget.file.name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatBytes(_totalBytes)} • ${_isUploading ? 'Processing...' : 'Done'}',
                    style: GoogleFonts.manrope(color: textSecondary, fontSize: 14),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Progress Percentage Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _isUploading ? 'UPLOADING' : 'COMPLETE',
                        style: GoogleFonts.manrope(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: GoogleFonts.manrope(
                          color: textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Linear Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 10,
                      backgroundColor: trackColor,
                      valueColor: AlwaysStoppedAnimation<Color>(scribeTeal),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Time Estimation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_outlined, color: textSecondary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _isUploading ? 'Estimated time: ${_getEstimatedTimeLeft()}' : 'Finished',
                        style: GoogleFonts.manrope(color: textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const Spacer(flex: 3),
            
            // 2. Cancel Action Button
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: TextButton(
                    onPressed: () {
                      _cancelUpload();
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: cancelButtonBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'Cancel Upload',
                      style: GoogleFonts.manrope(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
