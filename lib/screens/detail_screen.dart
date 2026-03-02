import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/meeting.dart';
import 'player_screen.dart';

class DetailScreen extends StatelessWidget {
  final Meeting meeting;
  const DetailScreen({super.key, required this.meeting});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A8C7E), Color(0xFF2DB5A5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 28),
                      Text(
                        meeting.duration,
                        style: const TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    meeting.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${meeting.date} • ${meeting.attendeeInitials.length} attendees',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Play button
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PlayerScreen(meeting: meeting)),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Listen Now',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _ActionCircle(icon: Icons.share_outlined, onTap: () {}),
                const SizedBox(width: 8),
                _ActionCircle(icon: Icons.more_horiz_rounded, onTap: () {}),
              ],
            ),
            const SizedBox(height: 32),

            // AI Summary
            Text('AI Summary', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Generated by AI',
                        style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The team discussed the upcoming Q4 roadmap, focusing on the mobile app overhaul. Key decisions included adopting a performance-first approach and prioritizing the Android experience. Sarah emphasized the importance of shipping before the holiday season.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Transcript
            Text('Transcript', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),

            _TranscriptEntry(
              speaker: 'Sarah Kim',
              initials: 'SK',
              time: '0:30',
              text: 'Alright everyone, let\'s kick off the Q4 planning. I want to start with our mobile strategy.',
            ),
            _TranscriptEntry(
              speaker: 'John Doe',
              initials: 'JD',
              time: '1:15',
              text: 'I think we should prioritize the performance audit first. Users have been reporting slow load times on older Android devices.',
            ),
            _TranscriptEntry(
              speaker: 'Alex Chen',
              initials: 'AC',
              time: '2:45',
              text: 'Agreed. I\'ve been looking at the flamegraphs and there are some clear bottlenecks in the rendering pipeline we can address.',
            ),
            _TranscriptEntry(
              speaker: 'Sarah Kim',
              initials: 'SK',
              time: '3:30',
              text: 'Perfect. Let\'s make that the top priority. We need to ship before the holiday season to capture the end-of-year traffic.',
            ),
            _TranscriptEntry(
              speaker: 'Maria Lopez',
              initials: 'ML',
              time: '4:10',
              text: 'I\'ll start the design system audit this week so we\'re ready when the performance work wraps up.',
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}

class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCircle({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: AppColors.textSecondary, size: 20),
        ),
      ),
    );
  }
}

class _TranscriptEntry extends StatelessWidget {
  final String speaker;
  final String initials;
  final String time;
  final String text;

  const _TranscriptEntry({
    required this.speaker,
    required this.initials,
    required this.time,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      speaker,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
