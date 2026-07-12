/// A meeting the user has scheduled inside Scribe. Stored in the app itself
/// (not the device calendar), so it works identically on every phone.
class ScheduledMeeting {
  final String id;
  final String title;

  /// Optional free-text notes about the meeting (agenda, link, attendees...).
  final String? description;

  /// Local start time. The default meeting length is one hour.
  final DateTime start;
  final int durationMinutes;

  const ScheduledMeeting({
    required this.id,
    required this.title,
    this.description,
    required this.start,
    this.durationMinutes = 60,
  });

  DateTime get end => start.add(Duration(minutes: durationMinutes));

  factory ScheduledMeeting.fromJson(Map<String, dynamic> json) {
    final rawDescription = json['description'] as String?;
    return ScheduledMeeting(
      id: json['id'] as String,
      title: json['title'] as String,
      description: (rawDescription != null && rawDescription.trim().isNotEmpty)
          ? rawDescription
          : null,
      start: DateTime.parse(json['start'] as String),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 60,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (description != null) 'description': description,
    'start': start.toIso8601String(),
    'durationMinutes': durationMinutes,
  };
}
