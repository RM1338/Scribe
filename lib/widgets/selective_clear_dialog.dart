import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/meeting_provider.dart';
import '../theme/app_theme.dart';

class SelectiveClearDialog extends StatefulWidget {
  const SelectiveClearDialog({super.key});

  @override
  State<SelectiveClearDialog> createState() => _SelectiveClearDialogState();
}

class _SelectiveClearDialogState extends State<SelectiveClearDialog> {
  bool _clearRecordings = false;
  bool _clearMetadata = false;
  bool _clearHistory = false;
  Map<String, int>? _sizes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSizes();
  }

  Future<void> _loadSizes() async {
    final provider = context.read<MeetingProvider>();
    final sizes = await provider.getCacheSizes();
    if (mounted) {
      setState(() {
        _sizes = sizes;
        _loading = false;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final textSecondary = context.appTextSecondary;
    final scribeTeal = context.appPrimary;

    return AlertDialog(
      backgroundColor: context.appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Selective Clear', style: context.dialogTitle),
      content: _loading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildOption(
                  'Audio Recordings',
                  _sizes?['recordings'] ?? 0,
                  _clearRecordings,
                  (v) => setState(() => _clearRecordings = v!),
                ),
                _buildOption(
                  'Search History',
                  _sizes?['history'] ?? 0,
                  _clearHistory,
                  (v) => setState(() => _clearHistory = v!),
                ),
                _buildOption(
                  'Metadata (Meetings & Folders)',
                  _sizes?['metadata'] ?? 0,
                  _clearMetadata,
                  (v) => setState(() => _clearMetadata = v!),
                  isDangerous: true,
                ),
                if (_clearMetadata)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Warning: This will delete all your transcripts and folder structure.',
                      style: GoogleFonts.manrope(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.manrope(color: textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: (_clearRecordings || _clearMetadata || _clearHistory)
              ? () {
                  context.read<MeetingProvider>().clearSelective(
                    recordings: _clearRecordings,
                    metadata: _clearMetadata,
                    history: _clearHistory,
                  );
                  Navigator.pop(context);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _clearMetadata ? Colors.redAccent : scribeTeal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Clear Selected',
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildOption(
    String title,
    int size,
    bool value,
    ValueChanged<bool?> onChanged, {
    bool isDangerous = false,
  }) {
    return CheckboxListTile(
      title: Text(
        title,
        style: GoogleFonts.manrope(
          color: isDangerous ? Colors.redAccent : context.appTextPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        _formatSize(size),
        style: GoogleFonts.manrope(
          color: context.appTextTertiary,
          fontSize: 12,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: isDangerous ? Colors.redAccent : context.appPrimary,
      checkColor: Colors.white,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      checkboxShape: const StadiumBorder(),
    );
  }
}
