import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';

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

  void _saveChanges() {
    final settings = context.read<SettingsProvider>();
    settings.userName = _nameController.text.trim();
    settings.userEmail = _emailController.text.trim();
    settings.userColorValue = _swatches[_selectedColorIndex].toARGB32();
    Navigator.pop(context);
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
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: _swatches[_selectedColorIndex].withValues(
                      alpha: 0.2,
                    ),
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: _swatches[_selectedColorIndex],
                    ),
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
    Color labelColor,
  ) {
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
          style: GoogleFonts.manrope(color: text, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: bg,
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
