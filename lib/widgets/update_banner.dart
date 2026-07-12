import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// A dismissible banner shown at the top of the Library when a newer build is
/// published in the `app_release` table. Tapping "Update" opens the download
/// page on the website. Renders nothing until it has confirmed an update is
/// available and not already dismissed for that version, so it can be dropped
/// into a layout unconditionally.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key, this.service});

  /// Injectable for tests; defaults to the real Supabase-backed service.
  final UpdateService? service;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  AppRelease? _release;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  String _dismissKey(AppRelease r) =>
      'dismissed_update_${r.latestVersion}+${r.latestBuild}';

  Future<void> _check() async {
    final service = widget.service ?? UpdateService();
    final release = await service.fetchLatest();
    if (release == null || !mounted) return;

    final info = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(info.buildNumber) ?? 0;
    final available = isUpdateAvailable(
      currentVersion: info.version,
      currentBuild: currentBuild,
      latestVersion: release.latestVersion,
      latestBuild: release.latestBuild,
    );
    if (!available || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_dismissKey(release)) ?? false) return;
    if (!mounted) return;

    setState(() => _release = release);
  }

  Future<void> _dismiss() async {
    final release = _release;
    if (release == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissKey(release), true);
    if (mounted) setState(() => _dismissed = true);
  }

  Future<void> _openDownload() async {
    final url = _release?.downloadUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final release = _release;
    if (release == null || _dismissed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: context.appPrimaryLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.appPrimary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.system_update_rounded,
              color: context.appPrimary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update available',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    release.releaseNotes?.trim().isNotEmpty == true
                        ? release.releaseNotes!.trim()
                        : 'Version ${release.latestVersion} is ready to download.',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _openDownload,
              style: TextButton.styleFrom(
                backgroundColor: context.appPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Update',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: context.appTextSecondary,
              ),
              tooltip: 'Dismiss',
              onPressed: _dismiss,
            ),
          ],
        ),
      ),
    );
  }
}
