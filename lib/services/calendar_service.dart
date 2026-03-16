import 'package:device_calendar/device_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class CalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  bool _isTimezoneInitialized = false;

  CalendarService() {
    _initializeTimeZones();
  }

  void _initializeTimeZones() {
    if (!_isTimezoneInitialized) {
      tz_data.initializeTimeZones();
      _isTimezoneInitialized = true;
    }
  }

  Future<bool> requestPermissions() async {
    // First try device_calendar API
    var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
    if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
      permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      if (!permissionsGranted.isSuccess || !permissionsGranted.data!) {
        // Fallback to permission_handler
        final status = await Permission.calendarFullAccess.request();
        return status.isGranted;
      }
    }
    return permissionsGranted.data ?? false;
  }

  Future<List<Calendar>> getCalendars() async {
    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    return calendarsResult.data as List<Calendar>? ?? [];
  }

  Future<List<Event>> getEventsForDate(DateTime date) async {
    final hasPermissions = await requestPermissions();
    if (!hasPermissions) return [];

    final calendars = await getCalendars();
    if (calendars.isEmpty) return [];

    final startOfDay = tz.TZDateTime.local(date.year, date.month, date.day);
    // End of day is start of next day
    final endOfDay = startOfDay.add(const Duration(days: 1));

    List<Event> allEvents = [];

    for (final calendar in calendars) {
      // Skip read-only or hidden calendars if desired, or just fetch all
      if (calendar.id == null) continue;

      final retrieveEventsParams = RetrieveEventsParams(
        startDate: startOfDay,
        endDate: endOfDay,
      );

      final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
        calendar.id,
        retrieveEventsParams,
      );

      if (eventsResult.isSuccess && eventsResult.data != null) {
        allEvents.addAll(eventsResult.data!);
      }
    }

    // Sort events by start time
    allEvents.sort((a, b) {
      if (a.start == null && b.start == null) return 0;
      if (a.start == null) return 1;
      if (b.start == null) return -1;
      return a.start!.compareTo(b.start!);
    });

    return allEvents;
  }

  Future<bool> addEvent(String title, DateTime startTime, DateTime endTime) async {
    final hasPermissions = await requestPermissions();
    if (!hasPermissions) return false;

    final calendars = await getCalendars();
    final writableCalendars = calendars.where((c) => c.isReadOnly == false).toList();
    if (writableCalendars.isEmpty) return false;

    final calendar = writableCalendars.first;
    
    final event = Event(
      calendar.id,
      title: title,
      start: tz.TZDateTime.from(startTime, tz.local),
      end: tz.TZDateTime.from(endTime, tz.local),
    );

    final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
    return result?.isSuccess ?? false;
  }
}
