import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/language.dart';
import '../widgets/language_picker.dart';
import '../providers/settings_provider.dart';
import '../providers/meeting_provider.dart';
import '../providers/auth_provider.dart';
import 'profile_screen.dart';
import '../widgets/selective_clear_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final meetingProvider = context.read<MeetingProvider>();

    final Color surfaceColor = context.appSurface;
    final Color textPrimary = context.appTextPrimary;
    final Color textSecondary = context.appTextSecondary;
    // We'll use our appSeparator for the Granola divider line
    final Color dividerColor = context.appSeparator;
    final Color scribeTeal = context.appPrimary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text('Settings', style: context.appBarTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. ACCOUNT
          _buildSectionHeader('ACCOUNT', textSecondary),
          _buildSettingsGroup([
            _buildSettingsTile(
              icon: Icons.person_rounded,
              title: 'Profile',
              subtitle: 'Manage your personal info',
              trailing: null,
              iconColor: scribeTeal,
              textColor: textPrimary,
              dividerColor: null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
          ], surfaceColor),
          const SizedBox(height: 24),

          // 2. PREFERENCES (Core Setting Toggles)
          _buildSectionHeader('PREFERENCES', textSecondary),
          _buildSettingsGroup([
            _buildToggleTile(
              icon: Icons.cloud_upload_rounded,
              title: 'Cloud Transcription',
              subtitle: 'Fast & Accurate AI models',
              value: settings.isCloudMode,
              onChanged: (v) => settings.isCloudMode = v,
              iconColor: scribeTeal,
              textColor: textPrimary,
              dividerColor: dividerColor,
            ),
            _buildSettingsTile(
              icon: Icons.language_rounded,
              title: 'Transcription Language',
              subtitle: null,
              trailing: settings.defaultLanguage,
              iconColor: scribeTeal,
              textColor: textPrimary,
              dividerColor: null,
              onTap: () async {
                final selected = await showLanguagePicker(
                  context,
                  title: 'Transcription Language',
                  selectedCode: AppLanguage.codeFor(settings.defaultLanguage),
                  includeAutoDetect: true,
                  onAutoDetect: () =>
                      settings.defaultLanguage = AppLanguage.autoDetect,
                );
                if (selected != null) settings.defaultLanguage = selected.name;
              },
            ),
          ], surfaceColor),
          const SizedBox(height: 24),

          // 3. AI INTELLIGENCE
          _buildSectionHeader('AI INTELLIGENCE', textSecondary),
          _buildSettingsGroup([
            _buildSettingsTile(
              icon: Icons.description_rounded,
              title: 'Summary Style',
              subtitle: null,
              trailing: _capitalize(settings.summaryStyle.name),
              iconColor: scribeTeal,
              textColor: textPrimary,
              dividerColor: dividerColor,
              onTap: () => _showSelectionDialog(
                context,
                'Summary Style',
                ['Bullet Points', 'Executive Summary', 'Detailed Narrative'],
                settings.summaryStyle.index,
                (index) => settings.summaryStyle = SummaryStyle.values[index],
              ),
            ),
            _buildToggleTile(
              icon: Icons.topic_rounded,
              title: 'Theme Detection',
              subtitle: 'Auto-detect key topics',
              value: settings.isThemeDetectionEnabled,
              onChanged: (v) => settings.isThemeDetectionEnabled = v,
              iconColor: scribeTeal,
              textColor: textPrimary,
              dividerColor: dividerColor,
            ),
            _buildToggleTile(
              icon: Icons.record_voice_over_rounded,
              title: 'Speaker ID',
              subtitle: 'Diarization & labeling',
              value: settings.isSpeakerIdEnabled,
              onChanged: (v) => settings.isSpeakerIdEnabled = v,
              iconColor: scribeTeal,
              textColor: textPrimary,
              dividerColor: null,
            ),
          ], surfaceColor),
          const SizedBox(height: 24),

          // 4. APPEARANCE
          _buildSectionHeader('APPEARANCE', textSecondary),
          _buildSettingsGroup([
            _buildToggleTile(
              icon: Icons.dark_mode_rounded,
              title: 'Dark Mode',
              subtitle: 'Switch between light and dark',
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (v) => settings.themeMode =
                  v ? ThemeModeOption.dark : ThemeModeOption.light,
              iconColor: scribeTeal,
              textColor: textPrimary,
              dividerColor: null,
            ),
          ], surfaceColor),
          const SizedBox(height: 24),

          // 5. ADVANCED
          _buildSectionHeader('ADVANCED', textSecondary),
          _buildSettingsGroup([
            _buildSettingsTile(
              icon: Icons.security_rounded,
              title: 'Privacy & Security',
              subtitle: null,
              trailing: null,
              iconColor: scribeTeal,
              textColor: textPrimary,
              dividerColor: dividerColor,
              onTap: () => _showPrivacyDialog(context),
            ),
            FutureBuilder<Map<String, int>>(
              future: meetingProvider.getCacheSizes(),
              builder: (context, snapshot) {
                int totalBytes = 0;
                if (snapshot.hasData) {
                  totalBytes = snapshot.data!.values.fold(
                    0,
                    (sum, next) => sum + next,
                  );
                }

                return _buildSettingsTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Clear Cache',
                  subtitle: null,
                  trailing: _formatBytes(totalBytes),
                  iconColor: scribeTeal,
                  textColor: textPrimary,
                  dividerColor: dividerColor,
                  onTap: () => showDialog(
                    context: context,
                    builder: (c) => const SelectiveClearDialog(),
                  ),
                );
              },
            ),
            _buildSettingsTile(
              icon: Icons.key_rounded,
              title: 'Groq API Key',
              subtitle: 'Use your own key instead of the shared server',
              trailing: settings.hasUserApiKey ? 'Personal' : 'Default',
              trailingColor: settings.hasUserApiKey ? scribeTeal : null,
              iconColor: scribeTeal,
              textColor: textPrimary,
              dividerColor: null,
              onTap: () => _showApiKeyDialog(context, settings),
            ),
          ], surfaceColor),
          const SizedBox(height: 40),

          Center(
            child: TextButton(
              onPressed: () => _confirmSignOut(context),
              child: Text(
                'Sign Out',
                style: context.buttonLabel.copyWith(color: AppColors.recordRed),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final auth = context.read<AuthProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        content: Text(
          'Your meetings and recordings stay on this device and will be here when you sign back in.',
          style: GoogleFonts.manrope(color: context.appTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                color: context.appPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Sign Out',
              style: GoogleFonts.manrope(
                color: AppColors.recordRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await auth.signOut();
    }
  }

  void _showApiKeyDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController();
    final hadKey = settings.hasUserApiKey;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final canSave = controller.text.trim().isNotEmpty;
          return AlertDialog(
            backgroundColor: context.appSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Groq API Key',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hadKey
                      ? 'A personal key is set — transcription and summaries use your own Groq account. Enter a new key to replace it, or remove it to go back to the shared server.'
                      : 'By default, Scribe uses a secure shared server for AI. Paste your own Groq API key to use your own account and quota instead. Get one at console.groq.com.',
                  style: GoogleFonts.manrope(
                    color: context.appTextSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.manrope(color: context.appTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'gsk_...',
                    hintStyle: GoogleFonts.manrope(
                      color: context.appTextSecondary.withValues(alpha: 0.5),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (hadKey)
                TextButton(
                  onPressed: () {
                    settings.groqApiKey = '';
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Remove',
                    style: GoogleFonts.manrope(
                      color: AppColors.recordRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.manrope(color: context.appTextSecondary),
                ),
              ),
              TextButton(
                onPressed: canSave
                    ? () {
                        settings.groqApiKey = controller.text.trim();
                        Navigator.pop(context);
                      }
                    : null,
                child: Text(
                  'Save',
                  style: GoogleFonts.manrope(
                    color: canSave
                        ? context.appPrimary
                        : context.appTextSecondary.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Privacy & Security',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _privacyItem(
              context,
              Icons.mic_off_rounded,
              'Audio Processing',
              'Recordings are processed on this device, or sent to your chosen cloud transcription provider. Scribe has no servers of its own.',
            ),
            const SizedBox(height: 16),
            _privacyItem(
              context,
              Icons.phone_android_rounded,
              'On-device Storage',
              'Recordings, transcripts and summaries are stored on this device only, in this app\'s private storage. They are not encrypted, and they are not backed up anywhere.',
            ),
            const SizedBox(height: 16),
            _privacyItem(
              context,
              Icons.delete_sweep_rounded,
              'Data Deletion',
              'You can delete your recordings, transcripts and history at any time from the Clear Cache option.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
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

  Widget _privacyItem(
    BuildContext context,
    IconData icon,
    String title,
    String desc,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.appPrimary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: GoogleFonts.manrope(
                  color: context.appTextSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _capitalize(String s) =>
      s[0].toUpperCase() +
      s.substring(1).replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}');

  void _showSelectionDialog(
    BuildContext context,
    String title,
    List<String> options,
    int currentIndex,
    Function(int) onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(title, style: context.dialogTitle),
            ),
            const SizedBox(height: 16),
            ...List.generate(options.length, (index) {
              final isSelected = currentIndex == index;
              return InkWell(
                onTap: () {
                  onSelected(index);
                  Navigator.pop(context);
                },
                hoverColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                focusColor: Colors.transparent,
                mouseCursor: SystemMouseCursors.basic,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        options[index],
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? context.appPrimary
                              : context.appTextPrimary,
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_rounded, color: context.appPrimary),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- Sub-widgets mapping exactly to the Granola Mockup specifications ---

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
      child: Builder(
        builder: (context) => Text(
          title.toUpperCase(),
          style: context.sectionLabel.copyWith(color: color),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children, Color surfaceColor) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        );
      },
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String? subtitle,
    required String? trailing,
    required Color iconColor,
    required Color textColor,
    Color? trailingColor,
    required Color? dividerColor,
    VoidCallback? onTap,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          mouseCursor: SystemMouseCursors.basic,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          focusColor: Colors.transparent,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(
            title,
            style: GoogleFonts.manrope(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null)
                Text(
                  trailing,
                  style: GoogleFonts.manrope(
                    color: trailingColor ?? textColor.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: trailingColor != null
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: textColor.withValues(alpha: 0.4),
                  size: 20,
                ),
              ],
            ],
          ),
          onTap: onTap,
        ),
        if (dividerColor != null)
          Divider(
            height: 1,
            indent: 72,
            endIndent: 16,
            color: dividerColor.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color iconColor,
    required Color textColor,
    required Color? dividerColor,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          mouseCursor: SystemMouseCursors.basic,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          focusColor: Colors.transparent,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(
            title,
            style: GoogleFonts.manrope(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                )
              : null,
          trailing: Transform.scale(
            scale: 0.9,
            child: Switch.adaptive(
              value: value,
              activeTrackColor: iconColor,
              onChanged: onChanged,
            ),
          ),
        ),
        if (dividerColor != null)
          Divider(
            height: 1,
            indent: 72,
            endIndent: 16,
            color: dividerColor.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  String _formatBytes(int bytes) {
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
}
