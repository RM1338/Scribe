import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class ScribeNewNoteScreen extends StatefulWidget {
  const ScribeNewNoteScreen({super.key});

  @override
  State<ScribeNewNoteScreen> createState() => _ScribeNewNoteScreenState();
}

class _ScribeNewNoteScreenState extends State<ScribeNewNoteScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  final String _selectedFolder = 'Select folder';
  final String _selectedDate = '10/27/2023';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: context.appTextPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('New Manual Note', style: context.appBarTitle),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              // Handle Save Logic
            },
            child: Text(
              'Save',
              style: context.buttonLabel.copyWith(color: context.appPrimary),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Note Content Card
            Container(
              height: 400,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: context.appShadowMedium,
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    style: GoogleFonts.manrope(
                      color: context.appTextPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Note Title',
                      hintStyle: GoogleFonts.manrope(
                        color: context.appTextSecondary.withValues(alpha: 0.4),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(height: 32),
                  Expanded(
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      style: GoogleFonts.manrope(
                        color: context.appTextPrimary,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Write your note...',
                        hintStyle: GoogleFonts.manrope(
                          color: context.appTextSecondary.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 2. Project Folder Selector
            _buildLabel('PROJECT FOLDER', context.appTextSecondary),
            _buildSelectorContainer(
              context.appSurface,
              context.appSeparator,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedFolder,
                    style: GoogleFonts.manrope(color: context.appTextSecondary),
                  ),
                  Icon(Icons.keyboard_arrow_down, color: context.appPrimary),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Date Selector
            _buildLabel('DATE', context.appTextSecondary),
            _buildSelectorContainer(
              context.appSurface,
              context.appSeparator,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDate,
                    style: GoogleFonts.manrope(
                      color: context.appTextPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(
                    Icons.calendar_today_outlined,
                    color: context.appPrimary,
                    size: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 4. Attachment Drop Zone
            // Trying to use a dashed border simulation or just solid as in the user snippet,
            // the provided image and user snippet specify: border.all(solid) but the image shows dashed.
            // Flutter doesn't have a native dashed border unless we use a package like dotted_border.
            // The provided snippet defaults to solid, so we'll stick to that.
            Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.appSeparator,
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    color: context.appTextSecondary.withValues(alpha: 0.5),
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add an image or attachment',
                    style: GoogleFonts.manrope(
                      color: context.appTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Builder(
        builder: (context) =>
            Text(text, style: context.sectionLabel.copyWith(color: color)),
      ),
    );
  }

  Widget _buildSelectorContainer(Color surface, Color border, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}
