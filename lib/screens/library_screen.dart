import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/meeting_provider.dart';
import '../models/meeting.dart';
import '../models/folder.dart';
import '../widgets/meeting_list_tile.dart';
import '../widgets/create_menu.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/update_banner.dart';

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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
              .where(
                (m) =>
                    m.title.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    (m.transcript?.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ??
                        false),
              )
              .toList();

    // Then apply tab filter
    switch (_selectedTab) {
      case 'Favorites':
        meetings = meetings.where((m) => m.isFavorite).toList();
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
        final allMeetings = provider.meetings;
        final meetings = _filterMeetings(allMeetings);

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text('Library', style: context.appBarTitleLarge),
            actions: [
              IconButton(
                icon: Icon(Icons.add, color: context.appTextPrimary),
                onPressed: () => showScribeCreateMenu(context),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: ProfileAvatar(),
              ),
            ],
          ),
          body: Column(
            children: [
              // Notifies the user when a newer build is on the website. Renders
              // nothing unless an update is actually available.
              const UpdateBanner(),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: context.appSurfaceVariant,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(color: context.appTextPrimary),
                    decoration: InputDecoration(
                      icon: Icon(Icons.search, color: context.appTextSecondary),
                      hintText: 'Search',
                      hintStyle: TextStyle(color: context.appTextSecondary),
                      border: InputBorder.none,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: context.appTextSecondary,
                                size: 20,
                              ),
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
                      _buildTab(
                        'Favorites',
                        _selectedTab == 'Favorites',
                        context,
                      ),
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
                    : meetings.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'No matches found'
                              : _selectedTab == 'Favorites'
                              ? 'No favorites yet'
                              : 'Your Scribe Library is Empty',
                          style: TextStyle(color: context.appTextSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: meetings.length,
                        itemBuilder: (context, index) {
                          final meeting = meetings[index];
                          return MeetingListTile(
                            meeting: meeting,
                            onFavoriteToggle: () =>
                                provider.toggleFavorite(meeting.id),
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

  Widget _buildFoldersView(
    BuildContext context,
    MeetingProvider provider,
    List<Meeting> allMeetings,
  ) {
    final folders = provider.folders;

    if (folders.isEmpty) {
      return Center(
        child: Text(
          'No folders yet. Create one from the + menu.',
          style: TextStyle(color: context.appTextSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        ...folders.map((folder) {
          final folderMeetings = allMeetings
              .where((m) => m.folderIds.contains(folder.id))
              .toList();
          return _FolderTile(
            folder: folder,
            meetings: folderMeetings,
            onToggleFavorite: provider.toggleFavorite,
            onDeleteMeeting: provider.deleteMeeting,
            onRemoveMeetingFromFolder: (meetingId) =>
                provider.removeMeetingFromFolder(meetingId, folder.id),
            onDeleteFolder: () => _confirmDeleteFolder(
              context,
              provider,
              folder.id,
              folder.name,
              folderMeetings.length,
            ),
          );
        }),
      ],
    );
  }

  Future<void> _confirmDeleteFolder(
    BuildContext context,
    MeetingProvider provider,
    String folderId,
    String folderName,
    int meetingCount,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Folder?',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        content: Text(
          meetingCount == 0
              ? 'Delete "$folderName"? This cannot be undone.'
              : 'Delete "$folderName"? The ${meetingCount == 1 ? 'meeting' : '$meetingCount meetings'} inside will be moved to Unfiled. This cannot be undone.',
          style: GoogleFonts.manrope(color: context.appTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.manrope()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              'Delete',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteFolder(folderId);
    }
  }

  Widget _buildTab(String title, bool isSelected, BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.appPrimary : context.appSurfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: GoogleFonts.manrope(
            color: isSelected ? Colors.white : context.appTextPrimary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// A collapsible folder row in the Folders tab. The delete affordance and the
/// expand chevron live together in [ExpansionTile.trailing] so both stay
/// vertically centred in the row -- keeping them in the title inflated it and
/// pushed the label off-centre.
class _FolderTile extends StatefulWidget {
  const _FolderTile({
    required this.folder,
    required this.meetings,
    required this.onToggleFavorite,
    required this.onDeleteMeeting,
    required this.onRemoveMeetingFromFolder,
    required this.onDeleteFolder,
  });

  final Folder folder;
  final List<Meeting> meetings;
  final void Function(String meetingId) onToggleFavorite;
  final void Function(String meetingId) onDeleteMeeting;
  final void Function(String meetingId) onRemoveMeetingFromFolder;
  final VoidCallback onDeleteFolder;

  @override
  State<_FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends State<_FolderTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final folder = widget.folder;
    final meetings = widget.meetings;

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
          onExpansionChanged: (v) => setState(() => _expanded = v),
          leading: Icon(
            Icons.folder_rounded,
            color: Color(folder.colorValue),
          ),
          title: Text(folder.name, style: context.cardTitle),
          subtitle: Text(
            '${meetings.length} meeting${meetings.length == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 12, color: context.appTextSecondary),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: context.appTextSecondary,
                  size: 20,
                ),
                tooltip: 'Delete folder',
                onPressed: widget.onDeleteFolder,
              ),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
          children: meetings.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No meetings in this folder',
                      style: TextStyle(color: context.appTextTertiary),
                    ),
                  ),
                ]
              : meetings
                    .map(
                      (m) => MeetingListTile(
                        meeting: m,
                        onFavoriteToggle: () => widget.onToggleFavorite(m.id),
                        onDelete: () => widget.onDeleteMeeting(m.id),
                        onRemoveFromFolder: () =>
                            widget.onRemoveMeetingFromFolder(m.id),
                      ),
                    )
                    .toList(),
        ),
      ),
    );
  }
}
