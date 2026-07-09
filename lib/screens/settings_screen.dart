import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../providers/meeting_provider.dart';
import 'profile_screen.dart';
import 'paywall_screen.dart';
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
        title: Text(
          'Settings',
          style: GoogleFonts.manrope(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. ACCOUNT
          _buildSectionHeader('ACCOUNT', textSecondary),
          _buildSettingsGroup(
            [
              _buildSettingsTile(
                icon: Icons.person_rounded,
                title: 'Profile',
                subtitle: 'Manage your personal info',
                trailing: null,
                iconColor: scribeTeal,
                textColor: textPrimary,
                dividerColor: dividerColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
              ),
              _buildSettingsTile(
                icon: Icons.star_rounded,
                title: 'Subscription',
                subtitle: null,
                trailing: settings.isPro ? 'Pro' : 'Free',
                trailingColor: scribeTeal,
                iconColor: scribeTeal,
                textColor: textPrimary,
                dividerColor: null,
                onTap: settings.isPro ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen())),
              ),
            ],
            surfaceColor,
          ),
          const SizedBox(height: 24),

          // 2. PREFERENCES (Core Setting Toggles)
          _buildSectionHeader('PREFERENCES', textSecondary),
          _buildSettingsGroup(
            [
              _buildToggleTile(
                icon: Icons.cloud_done_rounded,
                title: 'Cloud Sync',
                subtitle: 'Sync files across devices',
                value: !settings.isLocalOnlyMode,
                onChanged: (v) => settings.isLocalOnlyMode = !v,
                iconColor: scribeTeal,
                textColor: textPrimary,
                dividerColor: dividerColor,
              ),
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
                onTap: () => _showSelectionDialog(
                  context,
                  'Default Language',
                  ['Auto-detect', 'English', 'Spanish', 'French', 'German'],
                  ['Auto-detect', 'English', 'Spanish', 'French', 'German'].indexOf(settings.defaultLanguage),
                  (index) => settings.defaultLanguage = ['Auto-detect', 'English', 'Spanish', 'French', 'German'][index],
                ),
              ),
            ],
            surfaceColor,
          ),
          const SizedBox(height: 24),

          // 3. AI INTELLIGENCE
          _buildSectionHeader('AI INTELLIGENCE', textSecondary),
          _buildSettingsGroup(
            [
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
            ],
            surfaceColor,
          ),
          const SizedBox(height: 24),

          // 4. APPEARANCE
          _buildSectionHeader('APPEARANCE', textSecondary),
          _buildSettingsGroup(
            [
              _buildSelectionTile(
                title: 'System Default',
                icon: Icons.settings_system_daydream_rounded,
                isSelected: settings.themeMode == ThemeModeOption.system,
                onTap: () => settings.themeMode = ThemeModeOption.system,
                teal: scribeTeal,
                textColor: textPrimary,
                dividerColor: dividerColor,
              ),
              _buildSelectionTile(
                title: 'Light Mode',
                icon: Icons.light_mode_rounded,
                isSelected: settings.themeMode == ThemeModeOption.light,
                onTap: () => settings.themeMode = ThemeModeOption.light,
                teal: scribeTeal,
                textColor: textPrimary,
                dividerColor: dividerColor,
              ),
              _buildSelectionTile(
                title: 'Dark Mode',
                icon: Icons.dark_mode_rounded,
                isSelected: settings.themeMode == ThemeModeOption.dark,
                onTap: () => settings.themeMode = ThemeModeOption.dark,
                teal: scribeTeal,
                textColor: textPrimary,
                dividerColor: null,
              ),
            ],
            surfaceColor,
          ),
          const SizedBox(height: 24),

          // 5. ADVANCED
          _buildSectionHeader('ADVANCED', textSecondary),
          _buildSettingsGroup(
            [
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
                    totalBytes = snapshot.data!.values.fold(0, (sum, next) => sum + next);
                  }
                  
                  return _buildSettingsTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Clear Cache',
                    subtitle: null,
                    trailing: _formatBytes(totalBytes),
                    iconColor: scribeTeal,
                    textColor: textPrimary,
                    dividerColor: null,
                    onTap: () => showDialog(
                      context: context,
                      builder: (c) => const SelectiveClearDialog(),
                    ),
                  );
                }
              ),
            ],
            surfaceColor,
          ),
          const SizedBox(height: 40),

          // Scribe Version & Sign Out
          Center(
            child: Text(
              'Scribe v2.4.1 (Build 890)',
              style: GoogleFonts.manrope(color: context.appTextTertiary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () {},
              child: Text(
                'Sign Out',
                style: GoogleFonts.manrope(color: AppColors.recordRed, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
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
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: context.appTextPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _privacyItem(context, Icons.mic_off_rounded, 'Audio Processing',
                'Recordings are processed locally or via your chosen cloud provider. Audio is never stored on our servers.'),
            const SizedBox(height: 16),
            _privacyItem(context, Icons.lock_rounded, 'Data Encryption',
                'All transcripts and summaries are encrypted at rest on your device.'),
            const SizedBox(height: 16),
            _privacyItem(context, Icons.delete_sweep_rounded, 'Data Deletion',
                'You can delete all your data at any time from the Clear Cache option.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.manrope(color: context.appPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _privacyItem(BuildContext context, IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.appPrimary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: context.appTextPrimary, fontSize: 14)),
              const SizedBox(height: 4),
              Text(desc, style: GoogleFonts.manrope(color: context.appTextSecondary, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  String _capitalize(String s) =>
      s[0].toUpperCase() + s.substring(1).replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}');

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
              child: Text(
                title,
                style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w700, color: context.appTextPrimary),
              ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        options[index],
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? context.appPrimary : context.appTextPrimary,
                        ),
                      ),
                      if (isSelected) Icon(Icons.check_rounded, color: context.appPrimary),
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
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.manrope(color: color, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.2),
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
              )
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
          title: Text(title, style: GoogleFonts.manrope(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
          subtitle: subtitle != null
              ? Text(subtitle, style: GoogleFonts.manrope(color: textColor.withValues(alpha: 0.6), fontSize: 13))
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null)
                Text(
                  trailing,
                  style: GoogleFonts.manrope(color: trailingColor ?? textColor.withValues(alpha: 0.6), fontSize: 14, fontWeight: trailingColor != null ? FontWeight.w600 : FontWeight.w500),
                ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: textColor.withValues(alpha: 0.4), size: 20),
              ]
            ],
          ),
          onTap: onTap,
        ),
        if (dividerColor != null) Divider(height: 1, indent: 72, endIndent: 16, color: dividerColor.withValues(alpha: 0.5)),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
          title: Text(title, style: GoogleFonts.manrope(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
          subtitle: subtitle != null
              ? Text(subtitle, style: GoogleFonts.manrope(color: textColor.withValues(alpha: 0.6), fontSize: 13))
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
        if (dividerColor != null) Divider(height: 1, indent: 72, endIndent: 16, color: dividerColor.withValues(alpha: 0.5)),
      ],
    );
  }

  Widget _buildSelectionTile({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color teal,
    required Color textColor,
    required Color? dividerColor,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          mouseCursor: SystemMouseCursors.basic,
          tileColor: isSelected ? teal.withValues(alpha: 0.1) : Colors.transparent,
          shape: isSelected ? const StadiumBorder() : null,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          focusColor: Colors.transparent,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? Colors.transparent : teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: teal, size: 20),
          ),
          title: Text(title, style: GoogleFonts.manrope(color: isSelected ? teal : textColor, fontSize: 16, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
          trailing: isSelected ? Icon(Icons.check_circle_rounded, color: teal, size: 24) : null,
          onTap: onTap,
        ),
        if (dividerColor != null && !isSelected) Divider(height: 1, indent: 72, endIndent: 16, color: dividerColor.withValues(alpha: 0.5)),
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
