import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../models/scheduled_meeting.dart';

/// Local (on-device) reminders for meetings the user schedules in Scribe.
/// Independent of any calendar app -- works on every device.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'scheduled_meetings';

  static Future<void> init() async {
    // No local-notification support in browsers; reminders for web-scheduled
    // meetings fire on the user's phone once the schedule syncs down.
    if (kIsWeb) return;
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Falls back to UTC; reminders still fire, just anchored to UTC.
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  /// Prompts for notification permission (Android 13+ / iOS). Returns whether
  /// notifications are allowed. Safe to call repeatedly.
  static Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  /// Schedules two reminders for a meeting: a heads-up 5 minutes before it
  /// starts, and one at the start time itself. Past-due reminders are skipped
  /// individually (e.g. a meeting scheduled 2 minutes out still gets the
  /// start-time reminder). Re-scheduling the same meeting replaces both.
  static Future<void> scheduleMeetingReminder(ScheduledMeeting m) async {
    if (kIsWeb) return;
    await init();

    await _scheduleAt(
      id: _preIdFor(m.id),
      when: tz.TZDateTime.from(
        m.start.subtract(const Duration(minutes: 5)),
        tz.local,
      ),
      title: 'Meeting in 5 minutes',
      body: m.title,
    );

    await _scheduleAt(
      id: _idFor(m.id),
      when: tz.TZDateTime.from(m.start, tz.local),
      title: 'Meeting starting now',
      body: m.title,
    );
  }

  static Future<void> _scheduleAt({
    required int id,
    required tz.TZDateTime when,
    required String title,
    required String body,
  }) async {
    // Skip reminders whose fire time has already passed.
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Scheduled Meetings',
            channelDescription:
                'Reminders for meetings you schedule in Scribe',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      // Exact alarms can be unavailable on some setups; never let a reminder
      // failure break scheduling itself.
      debugPrint('NotificationService._scheduleAt error: $e');
    }
  }

  static Future<void> cancelMeetingReminder(String id) async {
    if (kIsWeb) return;
    await _plugin.cancel(_idFor(id));
    await _plugin.cancel(_preIdFor(id));
  }

  // Notification ids are 32-bit ints; meeting ids are millisecond strings.
  static int _idFor(String meetingId) => meetingId.hashCode & 0x7fffffff;

  // A distinct id for the 5-minutes-before heads-up of the same meeting.
  static int _preIdFor(String meetingId) =>
      ('pre_$meetingId').hashCode & 0x7fffffff;
}
