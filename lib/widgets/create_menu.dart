import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../screens/upload_selection_screen.dart';
import '../screens/new_note_screen.dart';
import 'create_folder_dialog.dart';
void showScribeCreateMenu(BuildContext context) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;

  // Scribe Design System Colors
  final Color bgColor = context.appSurface; // Typically bottom sheets use the surface color matching the modal intent
  final Color textPrimary = context.appTextPrimary;
  final Color textSecondary = context.appTextSecondary;
  final Color scribeTeal = context.appPrimary;

  showModalBottomSheet(
    context: context,
    backgroundColor: bgColor,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Bottom Sheet Handle
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // 2. Menu Title
            Text(
              'Create New',
              style: GoogleFonts.manrope(
                color: textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),

            // 3. Action Items
            _buildMenuAction(
              icon: Icons.cloud_upload_rounded,
              title: 'Upload Recording',
              subtitle: 'Upload an existing audio file',
              teal: scribeTeal,
              primary: textPrimary,
              secondary: textSecondary,
              onTap: () {
                Navigator.pop(context); // Close the bottom sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UploadSelectionScreen()),
                );
              },
            ),
            _buildMenuAction(
              icon: Icons.calendar_today_rounded,
              title: 'Schedule Meeting',
              subtitle: 'Plan a future recording session',
              teal: scribeTeal,
              primary: textPrimary,
              secondary: textSecondary,
              onTap: () => Navigator.pop(context),
            ),
            _buildMenuAction(
              icon: Icons.create_new_folder_rounded,
              title: 'Create Project Folder',
              subtitle: 'Organize your recordings and notes',
              teal: scribeTeal,
              primary: textPrimary,
              secondary: textSecondary,
              onTap: () {
                Navigator.pop(context); // Close the bottom sheet
                showScribeCreateFolderDialog(context);
              },
            ),
            _buildMenuAction(
              icon: Icons.edit_note_rounded,
              title: 'New Manual Note',
              subtitle: 'Start writing a note from scratch',
              teal: scribeTeal,
              primary: textPrimary,
              secondary: textSecondary,
              onTap: () {
                Navigator.pop(context); // Close the bottom sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScribeNewNoteScreen()),
                );
              },
            ),
            
            // Safety padding for devices with home indicators
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      );
    },
  );
}

Widget _buildMenuAction({
  required IconData icon,
  required String title,
  required String subtitle,
  required Color teal,
  required Color primary,
  required Color secondary,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: teal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: teal, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(color: primary, fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(color: secondary, fontSize: 13, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(Icons.chevron_right_rounded, color: secondary.withValues(alpha: 0.5), size: 24),
        ],
      ),
    ),
  );
}
