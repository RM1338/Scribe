import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HighlightsScreen extends StatelessWidget {
  const HighlightsScreen({super.key});

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
                'Highlights',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.8,
                ),
              ),
            ),
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: const [
                  _FilterChip(label: 'All', isSelected: true),
                  _FilterChip(label: 'Quotes'),
                  _FilterChip(label: 'Actions'),
                  _FilterChip(label: 'Decisions'),
                ],
              ),
            ),
          ),

          // Highlights List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _HighlightCard(index: index);
                },
                childCount: 5,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 160)),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final int index;
  const _HighlightCard({required this.index});

  @override
  Widget build(BuildContext context) {
    final types = ['Quote', 'Action', 'Decision', 'Quote', 'Action'];
    final icons = [
      Icons.format_quote_rounded,
      Icons.check_circle_outline_rounded,
      Icons.lightbulb_outline_rounded,
      Icons.format_quote_rounded,
      Icons.check_circle_outline_rounded,
    ];
    final colors = [
      AppColors.primary,
      AppColors.accent,
      const Color(0xFFE5A84B),
      AppColors.primary,
      AppColors.accent,
    ];
    final quotes = [
      '"We need to prioritize the mobile experience above everything else for Q4."',
      'Assign the design system audit to the UX team by end of week.',
      'Decided to postpone the API migration to Q1 next year.',
      '"The new onboarding flow has increased retention by 23% in the first week."',
      'Schedule a follow-up with the engineering team about performance benchmarks.',
    ];
    final speakers = [
      'Sarah Kim • Product Sync',
      'John Doe • Sprint Planning',
      'Alex Chen • Strategy Review',
      'Maria Lopez • Growth Meeting',
      'David Park • Eng Standup',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icons[index], size: 16, color: colors[index]),
              const SizedBox(width: 6),
              Text(
                types[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors[index],
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Text(
                '${2 + index}m ago',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            quotes[index],
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.5,
              letterSpacing: -0.2,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  speakers[index].substring(0, 1),
                  style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                speakers[index],
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _FilterChip({required this.label, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? AppColors.textPrimary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
