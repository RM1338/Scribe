import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/meeting.dart';

class PlayerScreen extends StatelessWidget {
  final Meeting meeting;

  const PlayerScreen({super.key, required this.meeting});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                    onPressed: () => Navigator.pop(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded),
                    color: AppColors.textSecondary,
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    // Artwork
                    Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A8C7E), Color(0xFF2DB5A5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 40,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 72),
                      ),
                    ),
                    const Spacer(flex: 2),

                    // Title
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meeting.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            meeting.team,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Scrubber
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        activeTrackColor: AppColors.textPrimary,
                        inactiveTrackColor: AppColors.separator,
                        thumbColor: AppColors.textPrimary,
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(value: 0.33, onChanged: (_) {}),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '14:52',
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                        Text(
                          '-30:08',
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_10_rounded, size: 32),
                          color: AppColors.textPrimary,
                          onPressed: () {},
                        ),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: AppColors.textPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.pause_rounded, size: 36, color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.forward_30_rounded, size: 32),
                          color: AppColors.textPrimary,
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const Spacer(flex: 2),

                    // Bottom actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.speed_rounded),
                          color: AppColors.textSecondary,
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.bookmark_outline_rounded),
                          color: AppColors.primary,
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.share_outlined),
                          color: AppColors.primary,
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.text_snippet_outlined),
                          color: AppColors.primary,
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
