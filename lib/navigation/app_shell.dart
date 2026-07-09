import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/library_screen.dart';
import '../screens/record_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/highlights_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/mini_player.dart';
import '../screens/player_screen.dart';
import 'package:provider/provider.dart';
import '../providers/meeting_provider.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  // ignore: library_private_types_in_public_api
  static final GlobalKey<_AppShellState> shellKey = GlobalKey<_AppShellState>();

  static void switchToTab(int index) {
    shellKey.currentState?.switchToTab(index);
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  void switchToTab(int index) {
    setState(() => _currentIndex = index);
  }

  final _screens = const [
    LibraryScreen(),
    RecordScreen(),
    ScheduleScreen(), // Replaced SearchScreen at index 2 for BottomNav
    HighlightsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      color: context.appBackground,
      child: Scaffold(
        backgroundColor: Colors.transparent, // Let AnimatedContainer handle background
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        floatingActionButton: _currentIndex == 0 
          ? FloatingActionButton(
              onPressed: () => setState(() => _currentIndex = 1),
              backgroundColor: context.appPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.mic, color: Colors.white, size: 28),
            )
          : null,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mini player
            Consumer<MeetingProvider>(
              builder: (context, provider, _) {
                final activeMeeting = provider.currentlyPlayingMeeting;
                if (activeMeeting == null) return const SizedBox.shrink();
                return MiniPlayer(
                  meeting: activeMeeting,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(
                          meeting: activeMeeting,
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // Clean bottom nav
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: context.appSurface,
                border: Border(
                  top: BorderSide(
                    color: context.appSeparator,
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _TabItem(
                        icon: Icons.folder_outlined,
                        activeIcon: Icons.folder_rounded,
                        label: 'Library',
                        isActive: _currentIndex == 0,
                        onTap: () => setState(() => _currentIndex = 0),
                      ),
                      _TabItem(
                        icon: Icons.calendar_today_outlined,
                        activeIcon: Icons.calendar_today_rounded,
                        label: 'Schedule',
                        isActive: _currentIndex == 2,
                        onTap: () => setState(() => _currentIndex = 2),
                      ),
                      _TabItem(
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings_rounded,
                        label: 'Settings',
                        isActive: _currentIndex == 4, // Keep index 4 for settings
                        onTap: () => setState(() => _currentIndex = 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? context.appPrimary : context.appTextTertiary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
