import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/meeting_provider.dart';
import '../models/meeting.dart';

/// Editor for a standalone note. Opened in two modes:
///  - create ([note] null): the record is created lazily on the first save, so
///    backing out of a blank editor leaves nothing behind.
///  - edit ([note] set): title and body write straight back to that meeting.
///
/// Like the in-recording notes field, there is no Save button -- content
/// persists when a field loses focus and when the screen closes.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.note});

  final Meeting? note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _bodyFocus = FocusNode();

  MeetingProvider? _provider;

  /// The note's id once it exists. Null in create mode until the first save,
  /// then set so later saves update rather than create duplicates.
  String? _id;

  @override
  void initState() {
    super.initState();
    _id = widget.note?.id;
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _bodyController = TextEditingController(text: widget.note?.notes ?? '');
    _titleFocus.addListener(_onFocusChange);
    _bodyFocus.addListener(_onFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<MeetingProvider>();
  }

  void _onFocusChange() {
    if (!_titleFocus.hasFocus && !_bodyFocus.hasFocus) _persist();
  }

  /// Writes the current fields. Creates the record on first call in create mode;
  /// updates it afterwards. A wholly empty note is never created.
  void _persist() {
    final provider = _provider;
    if (provider == null) return;

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (_id == null) {
      if (title.isEmpty && body.isEmpty) return;
      _id = provider.createNote(title: title, body: body);
    } else {
      // renameMeeting ignores an empty title, so a cleared title keeps the last
      // non-empty one rather than blanking the record.
      provider.renameMeeting(_id!, title.isEmpty ? 'Untitled Note' : title);
      provider.updateNotes(_id!, body);
    }
  }

  @override
  void dispose() {
    _persist();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.appTextPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.note == null ? 'New Note' : 'Note',
          style: context.appBarTitle,
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              focusNode: _titleFocus,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.manrope(
                color: context.appTextPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                hintText: 'Note title',
                hintStyle: GoogleFonts.manrope(
                  color: context.appTextSecondary.withValues(alpha: 0.4),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _bodyFocus.requestFocus(),
            ),
            const Divider(height: 28),
            Expanded(
              child: TextField(
                controller: _bodyController,
                focusNode: _bodyFocus,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.manrope(
                  color: context.appTextPrimary,
                  fontSize: 16,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: 'Write your note…',
                  hintStyle: GoogleFonts.manrope(
                    color: context.appTextSecondary.withValues(alpha: 0.5),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
