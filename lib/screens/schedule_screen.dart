import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_calendar/device_calendar.dart';
import '../theme/app_theme.dart';
import '../services/calendar_service.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/show_scribe_date_picker.dart';
import 'package:intl/intl.dart';
import '../navigation/app_shell.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final CalendarService _calendarService = CalendarService();
  int _selectedDateIndex = 0;
  late List<Map<String, dynamic>> _dates;
  late DateTime _now;
  DateTime _currentWeekStart = DateTime.now();

  List<Event> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _currentWeekStart = _now.subtract(Duration(days: _now.weekday - 1));
    _generateWeek();
    _selectedDateIndex = _dates.indexWhere(
      (d) => (d['fullDate'] as DateTime).day == _now.day,
    );
    if (_selectedDateIndex == -1) _selectedDateIndex = 0;
    _fetchEvents();
  }

  void _generateWeek() {
    _dates = List.generate(7, (index) {
      final date = _currentWeekStart.add(Duration(days: index));
      return {
        'day': ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][index],
        'date': date.day.toString(),
        'fullDate': date,
      };
    });
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    final selectedDate = _dates[_selectedDateIndex]['fullDate'] as DateTime;
    final events = await _calendarService.getEventsForDate(selectedDate);
    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  String _getMonthName(int month) {
    return [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ][month - 1];
  }

  Future<void> _openDatePicker() async {
    final DateTime currentSelected =
        _dates[_selectedDateIndex]['fullDate'] as DateTime;
    final DateTime? pickedDate = await showScribeDatePicker(
      context,
      currentSelected,
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _currentWeekStart = pickedDate.subtract(
          Duration(days: pickedDate.weekday - 1),
        );
        _generateWeek();
        _selectedDateIndex = pickedDate.weekday - 1;
      });
      _fetchEvents();
      _scheduleMeeting(preSelectedDate: pickedDate);
    }
  }

  Future<void> _scheduleMeeting({DateTime? preSelectedDate}) async {
    final titleController = TextEditingController(text: "New Scribe Meeting");
    final timeController = TextEditingController(text: "10:00");

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary = Theme.of(context).colorScheme.onSurface;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            "Schedule Meeting",
            style: GoogleFonts.manrope(color: textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: "Title",
                  labelStyle: TextStyle(
                    color: textPrimary.withValues(alpha: 0.6),
                  ),
                ),
              ),
              TextField(
                controller: timeController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: "Time (HH:MM)",
                  labelStyle: TextStyle(
                    color: textPrimary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Schedule"),
            ),
          ],
        );
      },
    );

    if (result == true) {
      try {
        final timeParts = timeController.text.split(":");
        if (timeParts.length == 2) {
          final int hour = int.parse(timeParts[0]);
          final int minute = int.parse(timeParts[1]);
          final selectedDate =
              preSelectedDate ??
              _dates[_selectedDateIndex]['fullDate'] as DateTime;

          final startTime = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            hour,
            minute,
          );
          final endTime = startTime.add(
            const Duration(hours: 1),
          ); // Default 1 hour meeting

          final success = await _calendarService.addEvent(
            titleController.text,
            startTime,
            endTime,
          );
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Meeting scheduled!',
                  style: GoogleFonts.manrope(),
                ),
              ),
            );
            _fetchEvents(); // Refresh events
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to schedule meeting.',
                  style: GoogleFonts.manrope(),
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Invalid time format.',
                style: GoogleFonts.manrope(),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color surfaceColor = context.appSurface;
    final Color textPrimary = context.appTextPrimary;
    final Color textSecondary = context.appTextSecondary;
    final Color scribeTeal = context.appPrimary;

    final currentMonth = _getMonthName(
      (_dates[_selectedDateIndex]['fullDate'] as DateTime).month,
    );
    final currentYear =
        (_dates[_selectedDateIndex]['fullDate'] as DateTime).year;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Schedule', style: context.appBarTitleLarge),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: textPrimary),
            onPressed: _scheduleMeeting,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: ProfileAvatar(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Month Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: GestureDetector(
              onTap: _openDatePicker,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '$currentMonth $currentYear',
                        style: context.sectionLabel,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: textSecondary,
                        size: 16,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentWeekStart = _currentWeekStart.subtract(
                              const Duration(days: 7),
                            );
                            _generateWeek();
                          });
                          _fetchEvents();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                          child: Icon(
                            Icons.chevron_left,
                            color: textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentWeekStart = _currentWeekStart.add(
                              const Duration(days: 7),
                            );
                            _generateWeek();
                          });
                          _fetchEvents();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                          child: Icon(
                            Icons.chevron_right,
                            color: textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2. Horizontal Date Picker
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _dates.length,
              itemBuilder: (context, index) {
                bool isSelected = _selectedDateIndex == index;
                bool isToday =
                    (_dates[index]['fullDate'] as DateTime).day == _now.day &&
                    (_dates[index]['fullDate'] as DateTime).month ==
                        _now.month &&
                    (_dates[index]['fullDate'] as DateTime).year == _now.year;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDateIndex = index);
                    _fetchEvents();
                  },
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? scribeTeal : Colors.transparent,
                      borderRadius: BorderRadius.circular(30),
                      border: isToday && !isSelected
                          ? Border.all(
                              color: scribeTeal.withValues(alpha: 0.3),
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _dates[index]['day']!,
                          style: GoogleFonts.manrope(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.8)
                                : textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dates[index]['date']!,
                          style: GoogleFonts.manrope(
                            color: isSelected ? Colors.white : textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Upcoming Meetings', style: context.sectionTitle),
                if (!_isLoading && _events.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scribeTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_events.length} Today',
                      style: GoogleFonts.manrope(
                        color: scribeTeal,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 3. Meeting List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: scribeTeal))
                : _events.isEmpty
                ? Center(
                    child: Text(
                      "No meetings scheduled.",
                      style: GoogleFonts.manrope(color: textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      final start = event.start != null
                          ? DateFormat.jm().format(event.start!)
                          : "?";
                      final end = event.end != null
                          ? DateFormat.jm().format(event.end!)
                          : "?";

                      return _buildMeetingCard(
                        event.title ?? "Untitled Meeting",
                        "$start - $end",
                        null, // Real live status calculation could go here
                        surfaceColor,
                        textPrimary,
                        textSecondary,
                        scribeTeal,
                        isDark,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingCard(
    String title,
    String time,
    String? status,
    Color surface,
    Color textPrimary,
    Color textSecondary,
    Color teal,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.cardTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: textSecondary, size: 14),
              const SizedBox(width: 6),
              Text(
                time,
                style: GoogleFonts.manrope(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (status != null)
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A8C7E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF1A8C7E),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else
                const SizedBox.shrink(),

              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      AppShell.switchToTab(1);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Join',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
