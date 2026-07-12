import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;

  // Profile Color selection state
  late int _selectedColorIndex;

  static const _swatches = AppColors.profileSwatches;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _nameController = TextEditingController(text: settings.userName);
    _emailController = TextEditingController(text: settings.userEmail);

    _selectedColorIndex = _swatches.indexOf(settings.userColor);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final settings = context.read<SettingsProvider>();
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final newName = _nameController.text.trim();
    final nameChanged = newName != settings.userName;

    // Email is read-only, so it's never written here.
    settings.userName = newName;
    settings.userColorValue = _swatches[_selectedColorIndex].toARGB32();

    // Push the name to Supabase so it's the same across devices/sessions.
    if (nameChanged && newName.isNotEmpty) {
      final ok = await auth.updateDisplayName(newName);
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              "Name saved on this device, but couldn't sync to the server.",
            ),
          ),
        );
      }
    }
    navigator.pop();
  }

  /// The photo is applied immediately (not on Save Changes), so the change is
  /// visible everywhere the avatar shows the moment it's picked.
  Future<void> _pickAvatar(ImageSource source) async {
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      await settings.setUserAvatar(picked.path);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't set that photo. Try again.")),
      );
    }
  }

  void _showAvatarOptions() {
    final settings = context.read<SettingsProvider>();
    final hasPhoto = settings.userAvatarPath != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.camera_alt_outlined,
                color: context.appTextPrimary,
              ),
              title: Text('Take Photo', style: GoogleFonts.manrope()),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAvatar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: context.appTextPrimary,
              ),
              title: Text('Choose from Gallery', style: GoogleFonts.manrope()),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  'Remove Photo',
                  style: GoogleFonts.manrope(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  settings.removeUserAvatar();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = context.appBackground;
    final Color surfaceColor = context.appSurface;
    final Color textPrimary = context.appTextPrimary;
    final Color textSecondary = context.appTextSecondary;
    final Color borderColor = context.appSeparator;
    final Color scribeTeal = context.appPrimary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Profile', style: context.appBarTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 32),

            // 1. Central Avatar Section
            Center(
              child: GestureDetector(
                onTap: _showAvatarOptions,
                child: Stack(
                  children: [
                    Builder(
                      builder: (context) {
                        final avatarPath = context
                            .watch<SettingsProvider>()
                            .userAvatarPath;
                        return CircleAvatar(
                          radius: 60,
                          backgroundColor: _swatches[_selectedColorIndex]
                              .withValues(alpha: 0.2),
                          backgroundImage: avatarPath != null
                              ? FileImage(File(avatarPath))
                              : null,
                          child: avatarPath == null
                              ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: _swatches[_selectedColorIndex],
                                )
                              : null,
                        );
                      },
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scribeTeal,
                          shape: BoxShape.circle,
                          border: Border.all(color: bgColor, width: 3),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),

            // 2. Input Fields
            _buildTextField(
              'Name',
              _nameController,
              surfaceColor,
              borderColor,
              textPrimary,
              textSecondary,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              'Email',
              _emailController,
              surfaceColor,
              borderColor,
              textPrimary,
              textSecondary,
              readOnly: true,
            ),
            const SizedBox(height: 40),

            // 3. Profile Color Swatches
            Align(
              alignment: Alignment.centerLeft,
              child: Text('PROFILE COLOR', style: context.sectionLabel),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_swatches.length, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedColorIndex = index),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _swatches[index],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColorIndex == index
                            ? scribeTeal
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: _selectedColorIndex == index
                        ? const Icon(Icons.check, color: Colors.white, size: 24)
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 60),

            // 4. Save Changes Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scribeTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text('Save Changes', style: context.buttonLabel),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    Color bg,
    Color border,
    Color text,
    Color labelColor, {
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            color: labelColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          // A read-only field (email) is dimmed and shows a "locked" affordance
          // so it's clear it can't be edited here.
          style: GoogleFonts.manrope(
            color: readOnly ? text.withValues(alpha: 0.5) : text,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: readOnly ? bg.withValues(alpha: 0.5) : bg,
            suffixIcon: readOnly
                ? Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: labelColor.withValues(alpha: 0.5),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.appPrimary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
