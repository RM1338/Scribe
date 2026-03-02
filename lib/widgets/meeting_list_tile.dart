import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/meeting.dart';
import '../screens/detail_screen.dart';

class MeetingListTile extends StatelessWidget {
  final Meeting meeting;

  const MeetingListTile({super.key, required this.meeting});

  Color get _statusColor {
    switch (meeting.status) {
      case MeetingStatus.transcribed:
        return AppColors.green;
      case MeetingStatus.inProgress:
        return AppColors.accent;
      case MeetingStatus.processing:
        return AppColors.primary;
    }
  }

  String get _statusText {
    switch (meeting.status) {
      case MeetingStatus.transcribed:
        return 'TRANSCRIBED';
      case MeetingStatus.inProgress:
        return 'IN PROGRESS';
      case MeetingStatus.processing:
        return 'PROCESSING';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DetailScreen(meeting: meeting)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.graphic_eq_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meeting.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${meeting.team} • ${meeting.duration}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
