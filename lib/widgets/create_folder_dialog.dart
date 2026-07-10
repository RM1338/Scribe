import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/meeting_provider.dart';

void showScribeCreateFolderDialog(BuildContext context) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;

  // Scribe Design System Colors
  final Color bgColor = context.appSurface;
  final Color textPrimary = context.appTextPrimary;
  final Color textSecondary = context.appTextSecondary;
  final Color borderColor = isDark
      ? const Color(0xFF2C2C2C)
      : const Color(0xFFE8E6E1);
  final Color scribeTeal = context.appPrimary;

  showDialog(
    context: context,
    builder: (context) {
      int selectedColorIndex = 0;
      final nameController = TextEditingController();
      final List<Color> swatchColors = [
        scribeTeal,
        const Color(0xFF4A5568), // Slate
        const Color(0xFF68D391), // Moss
        const Color(0xFFF6AD55), // Ochre
        const Color(0xFFFC8181), // Terracotta
      ];

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text('New Project Folder', style: context.dialogTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // 1. Folder Name Input
                Text('FOLDER NAME', style: context.sectionLabel),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  style: GoogleFonts.manrope(
                    color: textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Q4 Strategy Syncs',
                    hintStyle: GoogleFonts.manrope(
                      color: textSecondary.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.03),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: scribeTeal, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 2. Color Tag Selection
                Text('COLOR TAG', style: context.sectionLabel),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(swatchColors.length, (index) {
                    bool isSelected = selectedColorIndex == index;
                    return GestureDetector(
                      onTap: () => setState(() => selectedColorIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: swatchColors[index],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? scribeTeal : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: swatchColors[index].withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 24,
                              )
                            : null,
                      ),
                    );
                  }),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            actions: [
              // 3. Dialog Actions
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: context.buttonLabel.copyWith(
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = nameController.text.trim();
                        if (name.isNotEmpty) {
                          final provider = context.read<MeetingProvider>();
                          provider.createFolder(
                            name,
                            swatchColors[selectedColorIndex].toARGB32(),
                          );
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scribeTeal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('Create Folder', style: context.buttonLabel),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}
