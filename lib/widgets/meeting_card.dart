import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/meeting.dart';
import '../screens/detail_screen.dart';

class MeetingCard extends StatelessWidget {
  final Meeting meeting;

  const MeetingCard({super.key, required this.meeting});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DetailScreen(meeting: meeting)),
        );
      },
      child: Container(
        width: 165,
        height: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.appPrimaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.graphic_eq_rounded,
                color: context.appPrimary,
                size: 20,
              ),
            ),
            SizedBox(height: 14),
            Text(
              meeting.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
                letterSpacing: -0.2,
                color: context.appTextPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Spacer(),
            Text(
              meeting.date,
              style: TextStyle(fontSize: 12, color: context.appTextTertiary),
            ),
            SizedBox(height: 2),
            Text(
              meeting.duration,
              style: TextStyle(fontSize: 12, color: context.appTextTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
