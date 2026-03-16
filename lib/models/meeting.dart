import 'dart:convert';

enum MeetingStatus { transcribed, inProgress, processing }

class MeetingSegment {
  final double start;
  final double end;
  final String text;
  final String? speaker;

  const MeetingSegment({
    required this.start,
    required this.end,
    required this.text,
    this.speaker,
  });

  factory MeetingSegment.fromJson(Map<String, dynamic> json) {
    return MeetingSegment(
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      text: json['text'] as String,
      speaker: json['speaker'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'text': text,
        'speaker': speaker,
      };
}

class Meeting {
  final String id;
  final String title;
  final String team;
  final String date;
  final String duration;
  final MeetingStatus status;
  final List<String> attendeeInitials;
  final String? summary;
  final String? transcript;
  final String? audioFilePath;
  final List<String> actionItems;
  final List<String> highlights;
  final List<MeetingSegment> segments;
  final bool isFavorite;
  final String? folderId;
  final DateTime? recordedAt;
  final List<String> speakers;
  final List<String> tags;
  final List<String> topics;
  final String? sentiment;
  final bool isLocalOnly;
  final Map<String, String> speakerMapping;

  const Meeting({
    required this.id,
    required this.title,
    required this.team,
    required this.date,
    required this.duration,
    required this.status,
    this.attendeeInitials = const [],
    this.summary,
    this.transcript,
    this.audioFilePath,
    this.actionItems = const [],
    this.highlights = const [],
    this.segments = const [],
    this.isFavorite = false,
    this.folderId,
    this.recordedAt,
    this.speakers = const [],
    this.tags = const [],
    this.topics = const [],
    this.sentiment,
    this.isLocalOnly = false,
    this.speakerMapping = const {},
  });

  Meeting copyWith({
    String? id,
    String? title,
    String? team,
    String? date,
    String? duration,
    MeetingStatus? status,
    List<String>? attendeeInitials,
    String? summary,
    String? transcript,
    String? audioFilePath,
    List<String>? actionItems,
    List<String>? highlights,
    List<MeetingSegment>? segments,
    bool? isFavorite,
    String? folderId,
    DateTime? recordedAt,
    List<String>? speakers,
    List<String>? tags,
    List<String>? topics,
    String? sentiment,
    bool? isLocalOnly,
    Map<String, String>? speakerMapping,
  }) {
    return Meeting(
      id: id ?? this.id,
      title: title ?? this.title,
      team: team ?? this.team,
      date: date ?? this.date,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      attendeeInitials: attendeeInitials ?? this.attendeeInitials,
      summary: summary ?? this.summary,
      transcript: transcript ?? this.transcript,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      actionItems: actionItems ?? this.actionItems,
      highlights: highlights ?? this.highlights,
      segments: segments ?? this.segments,
      isFavorite: isFavorite ?? this.isFavorite,
      folderId: folderId ?? this.folderId,
      recordedAt: recordedAt ?? this.recordedAt,
      speakers: speakers ?? this.speakers,
      tags: tags ?? this.tags,
      topics: topics ?? this.topics,
      sentiment: sentiment ?? this.sentiment,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
      speakerMapping: speakerMapping ?? this.speakerMapping,
    );
  }

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['id'] as String,
      title: json['title'] as String,
      team: json['team'] as String,
      date: json['date'] as String,
      duration: json['duration'] as String,
      status: MeetingStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MeetingStatus.transcribed,
      ),
      attendeeInitials: List<String>.from(json['attendeeInitials'] ?? []),
      summary: json['summary'] as String?,
      transcript: json['transcript'] as String?,
      audioFilePath: json['audioFilePath'] as String?,
      actionItems: List<String>.from(json['actionItems'] ?? []),
      highlights: List<String>.from(json['highlights'] ?? []),
      segments: (json['segments'] as List<dynamic>? ?? [])
          .map((s) => MeetingSegment.fromJson(s as Map<String, dynamic>))
          .toList(),
      isFavorite: json['isFavorite'] as bool? ?? false,
      folderId: json['folderId'] as String?,
      recordedAt: json['recordedAt'] != null
          ? DateTime.tryParse(json['recordedAt'] as String)
          : null,
      speakers: List<String>.from(json['speakers'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      topics: List<String>.from(json['topics'] ?? []),
      sentiment: json['sentiment'] as String?,
      isLocalOnly: json['isLocalOnly'] as bool? ?? false,
      speakerMapping: Map<String, String>.from(json['speakerMapping'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'team': team,
        'date': date,
        'duration': duration,
        'status': status.name,
        'attendeeInitials': attendeeInitials,
        'summary': summary,
        'transcript': transcript,
        'audioFilePath': audioFilePath,
        'actionItems': actionItems,
        'highlights': highlights,
        'segments': segments.map((s) => s.toJson()).toList(),
        'isFavorite': isFavorite,
        'folderId': folderId,
        'recordedAt': recordedAt?.toIso8601String(),
        'speakers': speakers,
        'tags': tags,
        'topics': topics,
        'sentiment': sentiment,
        'isLocalOnly': isLocalOnly,
        'speakerMapping': speakerMapping,
      };

  String toJsonString() => jsonEncode(toJson());
}
