import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/meeting_provider.dart';
import '../providers/settings_provider.dart';
import '../models/meeting.dart';
import '../widgets/meeting_list_tile.dart';
import '../widgets/create_menu.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  StreamSubscription? _notificationSubscription;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTab = 'Recent';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MeetingProvider>();
      _notificationSubscription = provider.notificationStream.listen((message) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message, style: GoogleFonts.manrope()),
              backgroundColor: context.appPrimary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<Meeting> _filterMeetings(List<Meeting> all) {
    // First apply search filter
    var meetings = _searchQuery.isEmpty
        ? all
        : all
            .where((m) =>
                m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (m.transcript?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
            .toList();

    // Then apply tab filter
    switch (_selectedTab) {
      case 'Favorites':
        meetings = meetings.where((m) => m.isFavorite).toList();
        break;
      case 'Shared':
        meetings = []; // Shared feature not yet available
        break;
      case 'Folders':
        // Handled separately in the build method
        break;
      case 'Recent':
      default:
        break;
    }
    return meetings;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingProvider>(
      builder: (context, provider, _) {
        final settings = context.read<SettingsProvider>();
        final allMeetings = provider.meetings;
        final meetings = _filterMeetings(allMeetings);

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              'Library',
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: GoogleFonts.manrope().fontFamily,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.add, color: context.appTextPrimary),
                onPressed: () => showScribeCreateMenu(context),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: context.appPrimary,
                  child: Text(
                    settings.userName.isNotEmpty ? settings.userName[0].toUpperCase() : 'S',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: context.appSurfaceVariant,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(color: context.appTextPrimary, fontFamily: GoogleFonts.manrope().fontFamily),
                    decoration: InputDecoration(
                      icon: Icon(Icons.search, color: context.appTextSecondary),
                      hintText: 'Search',
                      hintStyle: TextStyle(color: context.appTextSecondary, fontFamily: GoogleFonts.manrope().fontFamily),
                      border: InputBorder.none,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close_rounded, color: context.appTextSecondary, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),

              // Tabs
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildTab('Recent', _selectedTab == 'Recent', context),
                      const SizedBox(width: 8),
                      _buildTab('Shared', _selectedTab == 'Shared', context),
                      const SizedBox(width: 8),
                      _buildTab('Favorites', _selectedTab == 'Favorites', context),
                      const SizedBox(width: 8),
                      _buildTab('Folders', _selectedTab == 'Folders', context),
                    ],
                  ),
                ),
              ),

              // Content
              Expanded(
                child: _selectedTab == 'Folders'
                    ? _buildFoldersView(context, provider, allMeetings)
                    : _selectedTab == 'Shared'
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.share_outlined, size: 48, color: context.appTextTertiary),
                                const SizedBox(height: 12),
                                Text(
                                  'Shared recordings will appear here',
                                  style: TextStyle(color: context.appTextSecondary, fontFamily: GoogleFonts.manrope().fontFamily),
                                ),
                              ],
                            ),
                          )
                        : meetings.isEmpty
                            ? Center(
                                child: Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No matches found'
                                      : _selectedTab == 'Favorites'
                                          ? 'No favorites yet'
                                          : 'Your Scribe Library is Empty',
                                  style: TextStyle(color: context.appTextSecondary, fontFamily: GoogleFonts.manrope().fontFamily),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: meetings.length,
                                itemBuilder: (context, index) {
                                  final meeting = meetings[index];
                                  return MeetingListTile(
                                    meeting: meeting,
                                    onFavoriteToggle: () => provider.toggleFavorite(meeting.id),
                                    onDelete: () => provider.deleteMeeting(meeting.id),
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFoldersView(BuildContext context, MeetingProvider provider, List<Meeting> allMeetings) {
    final folders = provider.folders;
    final unfoldered = allMeetings.where((m) => m.folderId == null).toList();

    if (folders.isEmpty && unfoldered.isEmpty) {
      return Center(
        child: Text(
          'No folders yet. Create one from the + menu.',
          style: TextStyle(color: context.appTextSecondary, fontFamily: GoogleFonts.manrope().fontFamily),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        ...folders.map((folder) {
          final folderMeetings = allMeetings.where((m) => m.folderId == folder.id).toList();
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: context.appShadowSubtle,
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: Icon(Icons.folder_rounded, color: Color(folder.colorValue)),
                title: Text(
                  folder.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: GoogleFonts.manrope().fontFamily,
                    color: context.appTextPrimary,
                  ),
                ),
                subtitle: Text(
                  '${folderMeetings.length} meeting${folderMeetings.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextSecondary,
                    fontFamily: GoogleFonts.manrope().fontFamily,
                  ),
                ),
                children: folderMeetings.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No meetings in this folder',
                            style: TextStyle(color: context.appTextTertiary, fontFamily: GoogleFonts.manrope().fontFamily),
                          ),
                        ),
                      ]
                    : folderMeetings
                        .map((m) => MeetingListTile(
                              meeting: m,
                              onFavoriteToggle: () => provider.toggleFavorite(m.id),
                              onDelete: () => provider.deleteMeeting(m.id),
                            ))
                        .toList(),
              ),
            ),
          );
        }),
        if (unfoldered.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12, left: 4),
            child: Text(
              'UNFILED',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: context.appTextTertiary,
                fontFamily: GoogleFonts.manrope().fontFamily,
              ),
            ),
          ),
          ...unfoldered.map((meeting) => MeetingListTile(
                meeting: meeting,
                onFavoriteToggle: () => provider.toggleFavorite(meeting.id),
                onDelete: () => provider.deleteMeeting(meeting.id),
              )),
        ],
      ],
    );
  }

  Widget _buildTab(String title, bool isSelected, BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.appPrimary : context.appSurfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : context.appTextPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontFamily: GoogleFonts.manrope().fontFamily,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
