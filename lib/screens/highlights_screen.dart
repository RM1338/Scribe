import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/meeting_provider.dart';
import '../models/meeting.dart';

class HighlightsScreen extends StatelessWidget {
  const HighlightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Consumer<MeetingProvider>(
        builder: (context, provider, _) {
          final allMeetings = provider.allMeetings;

          // Flatten all action items and highlights from all meetings
          final List<Map<String, dynamic>> allItems = [];
          for (final meeting in allMeetings) {
            for (final action in meeting.actionItems) {
              allItems.add({
                'type': 'Action',
                'text': action,
                'meeting': meeting,
                'icon': Icons.check_circle_outline_rounded,
                'color': context.appAccent,
              });
            }
            for (final highlight in meeting.highlights) {
              allItems.add({
                'type': 'Highlight',
                'text': highlight,
                'meeting': meeting,
                'icon': Icons.star_outline_rounded,
                'color': const Color(0xFFE5A84B),
              });
            }
          }

          // Sort descending by logic (assume newer meetings at start of list)
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 90,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
                  title: Text('Highlights', style: context.pageTitle),
                ),
              ),

              if (allItems.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          size: 64,
                          color: context.appTextTertiary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No highlights yet',
                          style: context.sectionTitle.copyWith(
                            color: context.appTextSecondary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Record a meeting to generate AI highlights',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.appTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = allItems[index];
                      return _HighlightCard(
                        type: item['type'] as String,
                        text: item['text'] as String,
                        meeting: item['meeting'] as Meeting,
                        icon: item['icon'] as IconData,
                        color: item['color'] as Color,
                      );
                    }, childCount: allItems.length),
                  ),
                ),

              SliverToBoxAdapter(child: SizedBox(height: 160)),
            ],
          );
        },
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final String type;
  final String text;
  final Meeting meeting;
  final IconData icon;
  final Color color;

  const _HighlightCard({
    required this.type,
    required this.text,
    required this.meeting,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              SizedBox(width: 6),
              Text(
                type,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.3,
                ),
              ),
              Spacer(),
              Text(
                meeting.date,
                style: TextStyle(fontSize: 12, color: context.appTextTertiary),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.5,
              letterSpacing: -0.2,
              color: context.appTextPrimary,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: context.appPrimary.withValues(alpha: 0.1),
                child: Text(
                  meeting.title.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: context.appPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  meeting.title,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
