import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/meeting_provider.dart';
import '../models/scheduled_meeting.dart';
import '../services/notification_service.dart';
import '../navigation/app_shell.dart';
import 'record_screen.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/show_scribe_date_picker.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int _selectedDateIndex = 0;
  late List<Map<String, dynamic>> _dates;
  late DateTime _now;
  DateTime _currentWeekStart = DateTime.now();

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

  DateTime get _selectedDate => _dates[_selectedDateIndex]['fullDate'] as DateTime;

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
    final DateTime? pickedDate = await showScribeDatePicker(
      context,
      _selectedDate,
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _currentWeekStart = pickedDate.subtract(
          Duration(days: pickedDate.weekday - 1),
        );
        _generateWeek();
        _selectedDateIndex = pickedDate.weekday - 1;
      });
      _scheduleMeeting(preSelectedDate: pickedDate);
    }
  }

  void _showScheduleError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.manrope())),
    );
  }

  Future<void> _scheduleMeeting({DateTime? preSelectedDate}) async {
    final titleController = TextEditingController(text: "New Scribe Meeting");
    final descriptionController = TextEditingController();
    TimeOfDay startClock = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay endClock = const TimeOfDay(hour: 11, minute: 0);

    final Color textPrimary = context.appTextPrimary;
    final Color scribeTeal = context.appPrimary;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            // A tappable clock row (alarm-clock style) for a labelled time.
            Widget timeRow(
              String label,
              TimeOfDay value,
              ValueChanged<TimeOfDay> onPicked,
            ) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: context.sectionLabel.copyWith(
                      color: context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: dialogContext,
                        initialTime: value,
                      );
                      if (picked != null) onPicked(picked);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: context.appSurfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            color: scribeTeal,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            value.format(dialogContext),
                            style: GoogleFonts.manrope(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.edit_outlined,
                            color: context.appTextSecondary,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return AlertDialog(
              backgroundColor: context.appSurface,
              title: Text(
                "Schedule Meeting",
                style: GoogleFonts.manrope(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    style: TextStyle(color: textPrimary),
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: "Description (optional)",
                      labelStyle: TextStyle(
                        color: textPrimary.withValues(alpha: 0.6),
                      ),
                      hintText: "Agenda, meeting link, attendees…",
                      hintStyle: TextStyle(
                        color: textPrimary.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  timeRow(
                    'STARTS',
                    startClock,
                    (t) => setDialogState(() => startClock = t),
                  ),
                  const SizedBox(height: 16),
                  timeRow(
                    'ENDS',
                    endClock,
                    (t) => setDialogState(() => endClock = t),
                  ),
                ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.manrope(color: context.appTextSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scribeTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text("Schedule"),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final date = preSelectedDate ?? _selectedDate;
    final startTime = DateTime(
      date.year,
      date.month,
      date.day,
      startClock.hour,
      startClock.minute,
    );
    final endTime = DateTime(
      date.year,
      date.month,
      date.day,
      endClock.hour,
      endClock.minute,
    );

    if (startTime.isBefore(DateTime.now())) {
      _showScheduleError("Can't schedule a meeting in the past.");
      return;
    }
    if (!endTime.isAfter(startTime)) {
      _showScheduleError("The end time must be after the start time.");
      return;
    }

    final title = titleController.text.trim().isEmpty
        ? 'New Scribe Meeting'
        : titleController.text.trim();
    final description = descriptionController.text.trim().isEmpty
        ? null
        : descriptionController.text.trim();
    final durationMinutes = endTime.difference(startTime).inMinutes;

    if (!mounted) return;
    final provider = context.read<MeetingProvider>();
    final messenger = ScaffoldMessenger.of(context);

    // Ask for notification permission so the reminder can actually fire.
    await NotificationService.requestPermissions();
    await provider.addScheduledMeeting(
      title,
      startTime,
      durationMinutes: durationMinutes,
      description: description,
    );
    if (!mounted) return;
    setState(() {}); // reflect the new meeting in the list
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Meeting scheduled! You\'ll get a reminder 5 minutes before.',
          style: GoogleFonts.manrope(),
        ),
      ),
    );
  }

  /// "Join now": confirm, then jump to the Record tab and start a recording
  /// pre-named after the meeting. Won't interrupt a recording already running.
  Future<void> _joinNow(ScheduledMeeting meeting) async {
    final provider = context.read<MeetingProvider>();
    if (provider.recordingState != RecordingState.idle) {
      _showScheduleError('A recording is already in progress.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Start recording now?',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scribe will begin recording "${meeting.title}".',
              style: GoogleFonts.manrope(color: context.appTextSecondary),
            ),
            if (meeting.description != null) ...[
              const SizedBox(height: 12),
              Text(
                meeting.description!,
                style: GoogleFonts.manrope(
                  color: context.appTextTertiary,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(color: context.appTextSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            icon: const Icon(Icons.mic_rounded, size: 18),
            label: Text(
              'Start recording',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Switch to the Record tab, then kick off recording with the meeting name.
    AppShell.switchToTab(1);
    final started = RecordScreen.startWithTitle(meeting.title);
    if (!started) _showScheduleError('A recording is already in progress.');
  }

  Future<void> _confirmDelete(ScheduledMeeting meeting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete scheduled meeting?',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        content: Text(
          '"${meeting.title}" will be removed from your schedule.',
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
    if (confirmed == true && mounted) {
      await context.read<MeetingProvider>().deleteScheduledMeeting(meeting.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color surfaceColor = context.appSurface;
    final Color textPrimary = context.appTextPrimary;
    final Color textSecondary = context.appTextSecondary;
    final Color scribeTeal = context.appPrimary;

    final provider = context.watch<MeetingProvider>();
    final meetings = provider.scheduledMeetingsOn(_selectedDate);

    final currentMonth = _getMonthName(_selectedDate.month);
    final currentYear = _selectedDate.year;

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
            onPressed: () => _scheduleMeeting(),
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
                  onTap: () => setState(() => _selectedDateIndex = index),
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
                if (meetings.isNotEmpty)
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
                      '${meetings.length} scheduled',
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
            child: meetings.isEmpty
                ? Center(
                    child: Text(
                      "No meetings scheduled.",
                      style: GoogleFonts.manrope(color: textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: meetings.length,
                    itemBuilder: (context, index) {
                      final m = meetings[index];
                      final time =
                          '${DateFormat.jm().format(m.start)} - ${DateFormat.jm().format(m.end)}';
                      return _buildMeetingCard(
                        m,
                        time,
                        surfaceColor,
                        textPrimary,
                        textSecondary,
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
    ScheduledMeeting meeting,
    String time,
    Color surface,
    Color textPrimary,
    Color textSecondary,
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.title,
                      style: context.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          color: textSecondary,
                          size: 14,
                        ),
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
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: textSecondary,
                  size: 20,
                ),
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(meeting),
              ),
            ],
          ),
          if (meeting.description != null) ...[
            const SizedBox(height: 8),
            Text(
              meeting.description!,
              style: GoogleFonts.manrope(
                color: textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _joinNow(meeting),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.mic_rounded, size: 18),
              label: Text(
                'Join now',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
