import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/meeting_provider.dart';
// import '../widgets/meeting_list_tile.dart';
import '../models/meeting.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onCategoryTap(String category) {
    setState(() {
      _selectedCategory = category;
      _query = '';
      _controller.clear();
    });
  }

  void _onSearchSubmit(String query, MeetingProvider provider) {
    if (query.isNotEmpty) {
      provider.addRecentSearch(query);
    }
  }

  String? _getSnippet(Meeting meeting, String query) {
    if (query.isEmpty) return null;
    final q = query.toLowerCase();

    // Check title (usually visible already, but for completeness)
    if (meeting.title.toLowerCase().contains(q)) return null;

    // Check summary
    if (meeting.summary != null && meeting.summary!.toLowerCase().contains(q)) {
      return _extractSnippet(meeting.summary!, q);
    }

    // Check transcript
    if (meeting.transcript != null &&
        meeting.transcript!.toLowerCase().contains(q)) {
      return _extractSnippet(meeting.transcript!, q);
    }

    return null;
  }

  String _extractSnippet(String text, String query) {
    final idx = text.toLowerCase().indexOf(query);
    if (idx == -1) return '';

    const contextSize = 40;
    final start = (idx - contextSize).clamp(0, text.length);
    final end = (idx + query.length + contextSize).clamp(0, text.length);

    String snippet = text.substring(start, end).replaceAll('\n', ' ');
    if (start > 0) snippet = '...$snippet';
    if (end < text.length) snippet = '$snippet...';

    return snippet;
  }

  bool _hasActiveFilters(MeetingProvider provider) {
    return provider.filterStartDate != null ||
        provider.filterSpeakers.isNotEmpty ||
        provider.filterTags.isNotEmpty ||
        provider.filterSentiment != null ||
        provider.filterActionItemsOnly;
  }

  void _showFilterSheet(BuildContext context, MeetingProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(provider: provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: Consumer<MeetingProvider>(
        builder: (context, provider, _) {
          final allMeetings = provider.allMeetings;

          List<Meeting> results = [];

          if (_selectedCategory != null ||
              _controller.text.isNotEmpty ||
              _hasActiveFilters(provider)) {
            // Get base results from provider's advanced search
            results = provider.searchMeetings(_controller.text);

            // Further filter by category if selected
            if (_selectedCategory != null) {
              results = results.where((m) {
                if (_selectedCategory == 'Action Items')
                  return m.actionItems.isNotEmpty;
                if (_selectedCategory == 'Key Decisions')
                  return m.highlights.isNotEmpty;
                if (_selectedCategory == 'Short Syncs') {
                  final mins = int.tryParse(m.duration.split(' ')[0]) ?? 0;
                  return mins < 5;
                }
                // For 'Favorites' category, filter from the already filtered results
                if (_selectedCategory == 'Favorites') return m.isFavorite;
                // For team categories
                return m.team == _selectedCategory;
              }).toList();
            }
          } else {
            // If no category, no search query, and no active filters, show all meetings
            results = allMeetings;
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 90,
                backgroundColor: context.appBackground,
                surfaceTintColor: Colors.transparent,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(
                    left: 20,
                    bottom: 14,
                    right: 20,
                  ),
                  title: _selectedCategory != null
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCategory = null),
                              child: Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 20,
                                  color: context.appTextPrimary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _selectedCategory!,
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                  color: context.appTextPrimary,
                                  letterSpacing: -0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${results.length} result${results.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.appTextTertiary,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        )
                      : Text('Search', style: context.pageTitle),
                ),
              ),

              // Search Bar (Only if no category is selected)
              if (_selectedCategory == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.appSurfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _controller,
                        onChanged: (val) => setState(() {
                          _query = val;
                          if (val.isNotEmpty) _selectedCategory = null;
                        }),
                        onSubmitted: (val) => _onSearchSubmit(val, provider),
                        style: TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Meetings, transcripts, summaries...',
                          hintStyle: TextStyle(color: context.appTextTertiary),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: context.appTextTertiary,
                            size: 20,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_query.isNotEmpty)
                                IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: context.appTextTertiary,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() {
                                      _query = '';
                                      _selectedCategory = null;
                                    });
                                    provider.clearAllFilters();
                                  },
                                ),
                              IconButton(
                                icon: Icon(
                                  Icons.tune_rounded,
                                  color: _hasActiveFilters(provider)
                                      ? context.appPrimary
                                      : context.appTextTertiary,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _showFilterSheet(context, provider),
                              ),
                            ],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Filter Chips
              if (_hasActiveFilters(provider) && _selectedCategory == null)
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        if (provider.filterStartDate != null)
                          _FilterChip(
                            label: 'Date Range',
                            onDeleted: () => provider.setDateRange(null, null),
                          ),
                        ...provider.filterSpeakers.map(
                          (s) => _FilterChip(
                            label: 'Speaker: $s',
                            onDeleted: () => provider.toggleSpeakerFilter(s),
                          ),
                        ),
                        ...provider.filterTags.map(
                          (t) => _FilterChip(
                            label: '#$t',
                            onDeleted: () => provider.toggleTagFilter(t),
                          ),
                        ),
                        if (provider.filterActionItemsOnly)
                          _FilterChip(
                            label: 'Action Items',
                            onDeleted: () => provider.setActionItemsOnly(false),
                          ),
                        if (provider.filterSentiment != null)
                          _FilterChip(
                            label: 'Sentiment: ${provider.filterSentiment}',
                            onDeleted: () => provider.setSentimentFilter(null),
                          ),
                      ],
                    ),
                  ),
                ),

              if (_query.isNotEmpty || _selectedCategory != null) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      children: [
                        Text(
                          'Results',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${results.length} result${results.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.appTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (results.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: context.appTextTertiary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No results found',
                            style: TextStyle(color: context.appTextSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
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
                        children: [
                          for (int i = 0; i < results.length; i++) ...[
                            _SearchListTile(
                              meeting: results[i],
                              query: _query,
                              snippet: _getSnippet(results[i], _query),
                              onTap: () {
                                if (_query.isNotEmpty)
                                  provider.addRecentSearch(_query);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DetailScreen(meeting: results[i]),
                                  ),
                                );
                              },
                              onFavoriteToggle: () =>
                                  provider.toggleFavorite(results[i].id),
                              onDelete: () =>
                                  provider.deleteMeeting(results[i].id),
                            ),
                            if (i < results.length - 1)
                              Divider(
                                height: 0.5,
                                indent: 72,
                                color: context.appSeparator,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ] else ...[
                // Recent Searches
                if (provider.recentSearches.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Row(
                        children: [
                          Text(
                            'Recent Searches',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.appTextSecondary,
                            ),
                          ),
                          Spacer(),
                          TextButton(
                            onPressed: () => provider.clearRecentSearches(),
                            child: Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.appPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: provider.recentSearches.length,
                        separatorBuilder: (_, _) => SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final s = provider.recentSearches[index];
                          return ActionChip(
                            label: Text(s),
                            backgroundColor: context.appSurfaceVariant,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            labelStyle: TextStyle(
                              fontSize: 13,
                              color: context.appTextSecondary,
                            ),
                            onPressed: () {
                              setState(() {
                                _query = s;
                                _controller.text = s;
                                _selectedCategory = null;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // Archives
                if (_selectedCategory == null) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
                      child: Text(
                        'Archives',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: context.appTextTertiary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.appSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.appSeparator.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          _ArchiveListTile(
                            label: 'Action Items',
                            icon: Icons.checklist_rtl_rounded,
                            color: const Color(0xFFE8856E),
                            onTap: () => _onCategoryTap('Action Items'),
                          ),
                          _ArchiveDivider(),
                          _ArchiveListTile(
                            label: 'Key Decisions',
                            icon: Icons.auto_awesome_rounded,
                            color: const Color(0xFF9B7FE6),
                            onTap: () => _onCategoryTap('Key Decisions'),
                          ),
                          _ArchiveDivider(),
                          _ArchiveListTile(
                            label: 'Short Syncs',
                            icon: Icons.timer_outlined,
                            color: const Color(0xFF4A9FD9),
                            onTap: () => _onCategoryTap('Short Syncs'),
                          ),
                          _ArchiveDivider(),
                          _ArchiveListTile(
                            label: 'Favorites',
                            icon: Icons.star_rounded,
                            color: const Color(0xFFE5A84B),
                            onTap: () => _onCategoryTap('Favorites'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (provider.uniqueTeams.isNotEmpty &&
                      (provider.uniqueTeams.length > 1 ||
                          provider.uniqueTeams.first != 'Personal')) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                        child: Text(
                          'Teams',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: context.appTextTertiary,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: context.appSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.appSeparator.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          children: [
                            for (
                              int i = 0;
                              i < provider.uniqueTeams.length;
                              i++
                            ) ...[
                              if (provider.uniqueTeams[i] != 'Personal' ||
                                  provider.uniqueTeams.length > 1) ...[
                                _ArchiveListTile(
                                  label: provider.uniqueTeams[i],
                                  icon: Icons.group_rounded,
                                  color: context.appPrimary,
                                  onTap: () =>
                                      _onCategoryTap(provider.uniqueTeams[i]),
                                ),
                                if (i < provider.uniqueTeams.length - 1)
                                  _ArchiveDivider(),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ],

              SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
    );
  }
}

class _ArchiveListTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ArchiveListTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.appTextPrimary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.appTextTertiary.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 60,
      color: context.appSeparator.withValues(alpha: 0.5),
    );
  }
}

class _SearchListTile extends StatelessWidget {
  final Meeting meeting;
  final String query;
  final String? snippet;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onDelete;

  const _SearchListTile({
    required this.meeting,
    required this.query,
    this.snippet,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.appSurfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.mic_none_rounded,
                color: context.appTextSecondary,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meeting.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: context.appTextPrimary,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  if (snippet != null) ...[
                    RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          color: context.appTextSecondary,
                          height: 1.4,
                        ),
                        children: _highlightSnippet(context, snippet!, query),
                      ),
                    ),
                  ] else ...[
                    Text(
                      '${meeting.date} • ${meeting.duration}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTextTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _highlightSnippet(
    BuildContext context,
    String snippet,
    String query,
  ) {
    if (query.isEmpty) return [TextSpan(text: snippet)];

    final List<TextSpan> spans = [];
    final lowerSnippet = snippet.toLowerCase();
    final lowerQuery = query.toLowerCase();

    int start = 0;
    while (true) {
      final index = lowerSnippet.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: snippet.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: snippet.substring(start, index)));
      }

      spans.add(
        TextSpan(
          text: snippet.substring(index, index + query.length),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
            backgroundColor: Color(0xFFFDF2B5), // Subtle yellow highlight
          ),
        ),
      );

      start = index + query.length;
    }

    return spans;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onDeleted;

  const _FilterChip({required this.label, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        backgroundColor: context.appPrimary.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide.none,
        ),
        onDeleted: onDeleted,
        deleteIcon: Icon(Icons.close_rounded, size: 14),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _FilterBottomSheet extends StatelessWidget {
  final MeetingProvider provider;

  const _FilterBottomSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingProvider>(
      builder: (context, provider, _) {
        return Container(
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Filters',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () {
                      provider.clearAllFilters();
                    },
                    child: Text('Reset All'),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Date Range
              Text('Date Range', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Row(
                children: [
                  _DateRangeButton(
                    label: 'Today',
                    selected:
                        provider.filterStartDate != null &&
                        _isSameDay(
                          provider.filterStartDate!,
                          DateTime.now().subtract(const Duration(hours: 24)),
                        ),
                    onTap: () => provider.setDateRange(
                      DateTime.now().subtract(const Duration(hours: 24)),
                      DateTime.now(),
                    ),
                  ),
                  SizedBox(width: 8),
                  _DateRangeButton(
                    label: 'This Week',
                    selected:
                        provider.filterStartDate != null &&
                        _isSameWeek(provider.filterStartDate!),
                    onTap: () => provider.setDateRange(
                      DateTime.now().subtract(const Duration(days: 7)),
                      DateTime.now(),
                    ),
                  ),
                  SizedBox(width: 8),
                  _CalendarButton(
                    selected:
                        provider.filterStartDate != null &&
                        !_isSameDay(
                          provider.filterStartDate!,
                          DateTime.now().subtract(const Duration(hours: 24)),
                        ) &&
                        !_isSameWeek(provider.filterStartDate!),
                    onTap: () async {
                      final range = await showModalBottomSheet<DateTimeRange>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => _GranolaDateRangePicker(
                          initialRange:
                              provider.filterStartDate != null &&
                                  provider.filterEndDate != null
                              ? DateTimeRange(
                                  start: provider.filterStartDate!,
                                  end: provider.filterEndDate!,
                                )
                              : null,
                        ),
                      );
                      if (range != null) {
                        provider.setDateRange(range.start, range.end);
                      }
                    },
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Speakers
              if (provider.uniqueSpeakers.isNotEmpty) ...[
                Text('Speakers', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: provider.uniqueSpeakers
                      .map(
                        (s) => FilterChip(
                          label: Text(s),
                          selected: provider.filterSpeakers.contains(s),
                          onSelected: (_) => provider.toggleSpeakerFilter(s),
                          backgroundColor: context.appSurfaceVariant,
                          selectedColor: context.appPrimary.withValues(
                            alpha: 0.2,
                          ),
                          checkmarkColor: context.appPrimary,
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: 24),
              ],

              // Tags
              if (provider.uniqueTags.isNotEmpty) ...[
                Text('Tags', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: provider.uniqueTags
                      .map(
                        (t) => FilterChip(
                          label: Text('#$t'),
                          selected: provider.filterTags.contains(t),
                          onSelected: (_) => provider.toggleTagFilter(t),
                          backgroundColor: context.appSurfaceVariant,
                          selectedColor: context.appPrimary.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: 24),
              ],

              SizedBox(height: 8),

              // Action Items Toggle
              SwitchListTile(
                title: Text(
                  'Action Items Only',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                subtitle: Text(
                  'Surface tasks extracted by AI',
                  style: TextStyle(fontSize: 13),
                ),
                value: provider.filterActionItemsOnly,
                onChanged: (val) => provider.setActionItemsOnly(val),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: context.appPrimary,
              ),

              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.appPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Show Results'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameWeek(DateTime a) {
    final now = DateTime.now();
    final diff = now.difference(a).inDays;
    return diff <= 7;
  }
}

class _GranolaDateRangePicker extends StatefulWidget {
  final DateTimeRange? initialRange;

  const _GranolaDateRangePicker({this.initialRange});

  @override
  State<_GranolaDateRangePicker> createState() =>
      _GranolaDateRangePickerState();
}

class _GranolaDateRangePickerState extends State<_GranolaDateRangePicker> {
  late DateTime _focusedMonth;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isMonthYearSelection = false;

  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialRange?.start;
    _endDate = widget.initialRange?.end;
    _focusedMonth = _startDate ?? DateTime.now();
  }

  void _onDayTap(DateTime day) {
    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        _startDate = day;
        _endDate = null;
      } else if (day.isBefore(_startDate!)) {
        _startDate = day;
      } else if (day.isAtSameMomentAs(_startDate!)) {
        _startDate = null;
      } else {
        _endDate = day;
      }
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isDuringRange(DateTime day) {
    if (_startDate == null || _endDate == null) return false;
    return day.isAfter(_startDate!) && day.isBefore(_endDate!);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appSeparator,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: context.appTextSecondary),
                  ),
                ),
                Text(
                  _startDate != null && _endDate != null
                      ? '${_startDate!.day} ${_months[_startDate!.month - 1].substring(0, 3)} – ${_endDate!.day} ${_months[_endDate!.month - 1].substring(0, 3)}'
                      : 'Select Range',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                TextButton(
                  onPressed: _startDate != null && _endDate != null
                      ? () => Navigator.pop(
                          context,
                          DateTimeRange(start: _startDate!, end: _endDate!),
                        )
                      : null,
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: _startDate != null && _endDate != null
                          ? context.appPrimary
                          : context.appTextTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 32),

          // Month/Year Selector Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left_rounded),
                  onPressed: () => setState(
                    () => _focusedMonth = DateTime(
                      _focusedMonth.year,
                      _focusedMonth.month - 1,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(
                    () => _isMonthYearSelection = !_isMonthYearSelection,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_months[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      Icon(
                        _isMonthYearSelection
                            ? Icons.arrow_drop_up_rounded
                            : Icons.arrow_drop_down_rounded,
                        color: context.appPrimary,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right_rounded),
                  onPressed: () => setState(
                    () => _focusedMonth = DateTime(
                      _focusedMonth.year,
                      _focusedMonth.month + 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          if (_isMonthYearSelection)
            _buildYearMonthPicker()
          else
            _buildDayPicker(),
        ],
      ),
    );
  }

  Widget _buildYearMonthPicker() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_left_rounded),
                onPressed: () => setState(
                  () => _focusedMonth = DateTime(
                    _focusedMonth.year - 1,
                    _focusedMonth.month,
                  ),
                ),
              ),
              Text(
                '${_focusedMonth.year}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              IconButton(
                icon: Icon(Icons.arrow_right_rounded),
                onPressed: () => setState(
                  () => _focusedMonth = DateTime(
                    _focusedMonth.year + 1,
                    _focusedMonth.month,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        SizedBox(
          height: 240,
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final isSelected = _focusedMonth.month == month;
              return InkWell(
                onTap: () => setState(() {
                  _focusedMonth = DateTime(_focusedMonth.year, month);
                  _isMonthYearSelection = false;
                }),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.appPrimary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? context.appPrimary
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    _months[index].substring(0, 3),
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? context.appPrimary
                          : context.appTextPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayPicker() {
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    final firstDayOffset =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7;
    final weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdayLabels
                .map(
                  (l) => Text(
                    l,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: daysInMonth + firstDayOffset,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 0,
            ),
            itemBuilder: (context, index) {
              if (index < firstDayOffset) return SizedBox();

              final day = index - firstDayOffset + 1;
              final date = DateTime(
                _focusedMonth.year,
                _focusedMonth.month,
                day,
              );
              final isStart =
                  _startDate != null && _isSameDay(date, _startDate!);
              final isEnd = _endDate != null && _isSameDay(date, _endDate!);
              final isRange = _isDuringRange(date);
              final isToday = _isSameDay(date, DateTime.now());

              return InkWell(
                onTap: () => _onDayTap(date),
                radius: 20,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isRange)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: context.appPrimaryLight,
                        ),
                      ),
                    if (isStart)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 25,
                          height: 32,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: _endDate != null
                                ? context.appPrimaryLight
                                : Colors.transparent,
                          ),
                        ),
                      ),
                    if (isEnd)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 25,
                          height: 32,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: context.appPrimaryLight,
                          ),
                        ),
                      ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isStart || isEnd
                            ? context.appPrimary
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: isToday && !isStart && !isEnd
                            ? Border.all(
                                color: context.appPrimary.withValues(
                                  alpha: 0.5,
                                ),
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: isStart || isEnd
                              ? Colors.white
                              : context.appTextPrimary,
                          fontWeight: isStart || isEnd || isToday
                              ? FontWeight.w700
                              : FontWeight.w400,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DateRangeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DateRangeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? context.appPrimary : context.appSurfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : context.appTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _CalendarButton({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? context.appPrimary : context.appSurfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.calendar_month_rounded,
          size: 20,
          color: selected ? Colors.white : context.appTextSecondary,
        ),
      ),
    );
  }
}
