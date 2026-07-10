import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/upload_progress_screen.dart';

class UploadSelectionScreen extends StatefulWidget {
  const UploadSelectionScreen({super.key});

  @override
  State<UploadSelectionScreen> createState() => _UploadSelectionScreenState();
}

class _UploadSelectionScreenState extends State<UploadSelectionScreen> {
  List<FileSystemEntity> _recentFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
  }

  Future<void> _loadRecentFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      // Look for audio/video files
      final files = directory.listSync().whereType<File>().where((file) {
        final ext = p.extension(file.path).toLowerCase();
        return ['.mp3', '.wav', '.mp4', '.mov', '.m4a'].contains(ext);
      }).toList();

      // Sort by modified date descending
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      if (mounted) {
        setState(() {
          _recentFiles = files.take(10).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'mp4', 'mov', 'm4a'],
    );

    if (result != null && result.files.single.path != null) {
      if (mounted) {
        // Navigate to progress screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UploadProgressScreen(file: result.files.single),
          ),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} mins ago';
    if (diff.inDays < 1) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  IconData _getIconForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case '.mp4':
      case '.mov':
        return Icons.play_circle_fill_rounded;
      case '.mp3':
      case '.m4a':
        return Icons.music_note_rounded;
      case '.wav':
      default:
        return Icons.description_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Scribe Design System Colors
    final Color bgColor = context.appBackground;
    final Color surfaceColor = context.appSurface;
    final Color textPrimary = context.appTextPrimary;
    final Color textSecondary = context.appTextSecondary;
    final Color scribeTeal = context.appPrimary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.05),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: textPrimary,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text('Upload Recording', style: context.appBarTitle),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // 1. Dashed Drop Zone Card
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                height: 280,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.3 : 0.05,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Custom Painter for dashed border
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _DashedBorderPainter(
                          color: scribeTeal.withValues(alpha: 0.3),
                          strokeWidth: 2,
                          gap: 8,
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: scribeTeal.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.cloud_upload_rounded,
                              color: scribeTeal,
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Tap to select files',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Supported: MP3, WAV, M4A, MP4, MOV',
                            style: GoogleFonts.manrope(
                              color: textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // 2. Recent Files Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Files', style: context.sectionTitle),
                if (_recentFiles.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      // Navigate to full library
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      alignment: Alignment.centerRight,
                    ),
                    child: Text(
                      'See all',
                      style: GoogleFonts.manrope(
                        color: scribeTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // 3. Recent Files List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _recentFiles.isEmpty
                  ? Center(
                      child: Text(
                        'No recent files found.',
                        style: GoogleFonts.manrope(color: textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _recentFiles.length,
                      itemBuilder: (context, index) {
                        final file = _recentFiles[index] as File;
                        final stat = file.statSync();
                        final ext = p.extension(file.path);
                        return _buildFileItem(
                          _getIconForExtension(ext),
                          p.basename(file.path),
                          '${_formatBytes(stat.size)} • ${_formatTimeAgo(stat.modified)}',
                          surfaceColor,
                          textPrimary,
                          textSecondary,
                          scribeTeal,
                          isDark,
                          () {
                            // Optionally handle tapping on a recent file.
                            // e.g., proceed to process it again or open it
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFileItem(
    IconData icon,
    String name,
    String info,
    Color surface,
    Color primary,
    Color secondary,
    Color scribeTeal,
    bool isDark,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scribeTeal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: scribeTeal),
        ),
        title: Text(
          name,
          style: AppText.cardTitle.copyWith(color: primary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          info,
          style: GoogleFonts.manrope(
            color: secondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: secondary.withValues(alpha: 0.5),
        ),
        onTap: onTap,
      ),
    );
  }
}

// Custom Painter for the Dashed Border Effect
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.gap = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rRect = RRect.fromLTRBR(
      0,
      0,
      size.width,
      size.height,
      const Radius.circular(24),
    );
    final Path path = Path()..addRRect(rRect);

    final Path dashPath = Path();
    double distance = 0.0;
    for (var i in path.computeMetrics()) {
      while (distance < i.length) {
        dashPath.addPath(i.extractPath(distance, distance + gap), Offset.zero);
        distance += gap * 2;
      }
      distance =
          0.0; // Reset for the next metric (though usually there is only one for RRect)
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
