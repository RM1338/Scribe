import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 90,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
              title: const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.8,
                ),
              ),
            ),
          ),

          // Profile Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary,
                      child: const Text(
                        'JD',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'John Doe',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'john@acmecorp.com',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),

          // General Section
          _SectionHeader(title: 'General'),
          _SettingsGroup(children: [
            _SettingsTile(
              icon: Icons.language_rounded,
              iconBg: const Color(0xFF4A9FD9),
              title: 'Language',
              trailing: 'English',
            ),
            _SettingsTile(
              icon: Icons.dark_mode_rounded,
              iconBg: const Color(0xFF6B6B6B),
              title: 'Appearance',
              trailing: 'Light',
            ),
            _SettingsTile(
              icon: Icons.notifications_none_rounded,
              iconBg: AppColors.recordRed,
              title: 'Notifications',
            ),
          ]),

          // Transcription Section
          _SectionHeader(title: 'Transcription'),
          _SettingsGroup(children: [
            _SettingsToggleTile(
              icon: Icons.auto_fix_high_rounded,
              iconBg: AppColors.primary,
              title: 'Auto-transcribe',
              value: true,
            ),
            _SettingsTile(
              icon: Icons.translate_rounded,
              iconBg: const Color(0xFFE5A84B),
              title: 'Transcription Language',
              trailing: 'Auto-detect',
            ),
            _SettingsTile(
              icon: Icons.smart_toy_outlined,
              iconBg: const Color(0xFF9B7FE6),
              title: 'AI Model',
              trailing: 'GPT-4o',
            ),
          ]),

          // Integrations Section
          _SectionHeader(title: 'Integrations'),
          _SettingsGroup(children: [
            _SettingsTile(
              icon: Icons.videocam_rounded,
              iconBg: const Color(0xFF4A9FD9),
              title: 'Zoom',
              trailing: 'Connected',
            ),
            _SettingsTile(
              icon: Icons.calendar_today_rounded,
              iconBg: const Color(0xFFE8856E),
              title: 'Google Calendar',
              trailing: 'Connected',
            ),
            _SettingsTile(
              icon: Icons.cloud_upload_outlined,
              iconBg: const Color(0xFF9B7FE6),
              title: 'Cloud Storage',
              trailing: 'Dropbox',
            ),
          ]),

          // About Section
          _SectionHeader(title: 'About'),
          _SettingsGroup(children: [
            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              iconBg: AppColors.textSecondary,
              title: 'Privacy & Data',
            ),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              iconBg: AppColors.textTertiary,
              title: 'About MeetNote',
            ),
            _SettingsTile(
              icon: Icons.help_outline_rounded,
              iconBg: AppColors.primary,
              title: 'Help & Support',
            ),
          ]),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Version
          SliverToBoxAdapter(
            child: Center(
              child: Text(
                'MeetNote v1.0.0',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 160)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Divider(
                  height: 0.5,
                  indent: 56,
                  color: AppColors.separator,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String? trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _SettingsToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final bool value;

  const _SettingsToggleTile({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.green,
            onChanged: (v) {},
          ),
        ],
      ),
    );
  }
}
