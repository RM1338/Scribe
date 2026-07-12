import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';

/// The signed-in user's avatar, tinted with the color they picked in Edit
/// Profile. Use this everywhere the user is represented so the color stays
/// consistent across screens.
///
/// Tapping it opens Edit Profile. That default lives here rather than at each
/// call site so the avatar behaves the same wherever it appears; pass [onTap]
/// only to override it.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.radius = 16, this.onTap});

  final double radius;
  final VoidCallback? onTap;

  void _openProfile(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final avatarPath = settings.userAvatarPath;

    return Semantics(
      button: true,
      label: 'Edit profile',
      child: GestureDetector(
        onTap: onTap ?? () => _openProfile(context),
        // The avatar is small; let the padding around it take the tap too.
        behavior: HitTestBehavior.opaque,
        child: CircleAvatar(
          radius: radius,
          backgroundColor: settings.userColor,
          backgroundImage: avatarPath != null
              ? FileImage(File(avatarPath))
              : null,
          child: avatarPath == null
              ? Text(
                  settings.userInitial,
                  style: AppText.cardTitle.copyWith(
                    color: Colors.white,
                    fontSize: radius * 0.85,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
