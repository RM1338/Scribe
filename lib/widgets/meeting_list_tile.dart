import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/meeting_provider.dart';
import '../models/meeting.dart';
import '../screens/detail_screen.dart';
import '../screens/note_editor_screen.dart';

class MeetingListTile extends StatelessWidget {
  final Meeting meeting;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onDelete;

  /// When set, adds a "Remove from folder" menu item. Used in the Folders tab
  /// to pull a meeting out of the folder it's listed under, without deleting it.
  final VoidCallback? onRemoveFromFolder;

  const MeetingListTile({
    super.key,
    required this.meeting,
    this.onFavoriteToggle,
    this.onDelete,
    this.onRemoveFromFolder,
  });

  @override
  Widget build(BuildContext context) {
    final bool isNote = meeting.isNote;
    final bool isTranscribed = meeting.status == MeetingStatus.transcribed;
    final String statusText = isNote
        ? 'NOTE'
        : (isTranscribed ? 'TRANSCRIBED' : 'PROCESSING');

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => isNote
                ? NoteEditorScreen(note: meeting)
                : DetailScreen(meeting: meeting),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: context.appShadowSubtle,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side: Title and Duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meeting.title,
                    style: context.cardTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: context.appTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        meeting.date,
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isNote)
                    Text(
                      (meeting.notes?.trim().isNotEmpty ?? false)
                          ? meeting.notes!.trim()
                          : 'Empty note',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.appTextSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: context.appTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          meeting.duration,
                          style: TextStyle(
                            color: context.appTextSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (meeting.notes?.isNotEmpty ?? false) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.sticky_note_2_outlined,
                            size: 14,
                            color: context.appPrimary,
                          ),
                        ],
                        if (meeting.speakerMapping.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 40,
                            height: 20,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: context.appPrimaryLight,
                                    child: Text(
                                      meeting.speakerMapping.values.first[0]
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: context.appPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                if (meeting.speakerMapping.length > 1)
                                  Positioned(
                                    left: 14,
                                    child: CircleAvatar(
                                      radius: 10,
                                      backgroundColor:
                                          context.appSurfaceVariant,
                                      child: Text(
                                        meeting.speakerMapping.values
                                            .elementAt(1)[0]
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: context.appTextPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right side: Status and More
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isTranscribed && !isNote)
                        ? context.appPrimary
                        : context.appSurfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.manrope(
                      color: (isTranscribed && !isNote)
                          ? Colors.white
                          : context.appTextPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Consumer<MeetingProvider>(
                  builder: (context, provider, _) => PopupMenuButton<String>(
                    color: context.appSurface,
                    surfaceTintColor: Colors.transparent,
                    position: PopupMenuPosition.under,
                    offset: const Offset(0, 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: context.appTextSecondary,
                    ),
                    padding: EdgeInsets.zero,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'favorite',
                        child: Text(
                          meeting.isFavorite ? 'Unfavorite' : 'Favorite',
                          style: GoogleFonts.manrope(),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename', style: GoogleFonts.manrope()),
                      ),
                      if (onRemoveFromFolder != null)
                        PopupMenuItem(
                          value: 'remove_from_folder',
                          child: Text(
                            'Remove from folder',
                            style: GoogleFonts.manrope(),
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: GoogleFonts.manrope(color: Colors.red),
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'favorite' && onFavoriteToggle != null) {
                        onFavoriteToggle!();
                      } else if (value == 'rename') {
                        final newTitle = await _showRenameDialog(
                          context,
                          meeting.title,
                        );
                        if (newTitle != null)
                          provider.renameMeeting(meeting.id, newTitle);
                      } else if (value == 'remove_from_folder') {
                        onRemoveFromFolder?.call();
                      } else if (value == 'delete') {
                        final confirm = await _showDeleteConfirm(context);
                        if (confirm == true && onDelete != null) onDelete!();
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Rename',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.appPrimary, width: 1.5),
            ),
          ),
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
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
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
}
