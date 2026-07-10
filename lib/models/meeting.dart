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

/// One meeting's content rendered into a single target language.
///
/// [segmentTexts] is positional: entry `i` is the translation of
/// `Meeting.segments[i]`. Keeping it aligned rather than re-storing timestamps
/// means the player's seek and highlight logic works on translated text for
/// free -- see [Meeting.segmentsIn].
///
/// A translation is only valid for the segments it was produced from. If a
/// meeting is ever re-transcribed its segments change, so [isStaleFor] checks
/// the count before anything trusts the alignment.
class MeetingTranslation {
  final String languageCode;
  final List<String> segmentTexts;
  final String? summary;
  final List<String> actionItems;
  final List<String> highlights;
  final List<String> topics;
  final DateTime translatedAt;

  const MeetingTranslation({
    required this.languageCode,
    required this.segmentTexts,
    required this.translatedAt,
    this.summary,
    this.actionItems = const [],
    this.highlights = const [],
    this.topics = const [],
  });

  bool isStaleFor(List<MeetingSegment> segments) =>
      segmentTexts.length != segments.length;

  factory MeetingTranslation.fromJson(Map<String, dynamic> json) {
    return MeetingTranslation(
      languageCode: json['languageCode'] as String,
      segmentTexts: List<String>.from(json['segmentTexts'] ?? []),
      summary: json['summary'] as String?,
      actionItems: List<String>.from(json['actionItems'] ?? []),
      highlights: List<String>.from(json['highlights'] ?? []),
      topics: List<String>.from(json['topics'] ?? []),
      translatedAt:
          DateTime.tryParse(json['translatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'languageCode': languageCode,
    'segmentTexts': segmentTexts,
    'summary': summary,
    'actionItems': actionItems,
    'highlights': highlights,
    'topics': topics,
    'translatedAt': translatedAt.toIso8601String(),
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
  final Map<String, String> speakerMapping;
  final String? detectedLanguage;

  /// Cached translations, keyed by ISO-639-1 code. Populated on demand.
  final Map<String, MeetingTranslation> translations;

  /// Indices into [actionItems] that the user has ticked off.
  ///
  /// Indices, not the item text: an item keeps its tick when the summary is
  /// viewed in another language, because [MeetingTranslation.actionItems] is
  /// positionally aligned with [actionItems]. Storing the text would lose the
  /// tick the moment anything was translated or re-summarised.
  final Set<int> completedActionItems;

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
    this.speakerMapping = const {},
    this.detectedLanguage,
    this.translations = const {},
    this.completedActionItems = const {},
  });

  bool isActionItemCompleted(int index) => completedActionItems.contains(index);

  int get completedActionItemCount => completedActionItems
      .where((i) => i >= 0 && i < actionItems.length)
      .length;

  /// The segments as they should be displayed in [languageCode]: the original
  /// timings, carrying translated text.
  ///
  /// Falls back to the untranslated segments when [languageCode] is null, has
  /// no cached translation, or has one that no longer lines up with the
  /// segments. The player is never handed a mismatched list.
  List<MeetingSegment> segmentsIn(String? languageCode) {
    if (languageCode == null) return segments;
    final translation = translations[languageCode];
    if (translation == null || translation.isStaleFor(segments)) {
      return segments;
    }

    return [
      for (var i = 0; i < segments.length; i++)
        MeetingSegment(
          start: segments[i].start,
          end: segments[i].end,
          text: translation.segmentTexts[i],
          speaker: segments[i].speaker,
        ),
    ];
  }

  /// Whether a usable (non-stale) translation exists for [languageCode].
  bool hasTranslation(String languageCode) {
    final translation = translations[languageCode];
    return translation != null && !translation.isStaleFor(segments);
  }

  /// The cached translation for [languageCode], or null when there isn't a
  /// usable one. Staleness is judged against [segments], so a meeting that was
  /// re-transcribed reports every old translation as missing.
  MeetingTranslation? _usableTranslation(String? languageCode) {
    if (languageCode == null) return null;
    final translation = translations[languageCode];
    if (translation == null || translation.isStaleFor(segments)) return null;
    return translation;
  }

  String? summaryIn(String? languageCode) =>
      _usableTranslation(languageCode)?.summary ?? summary;

  /// Each falls back to the original when the translation is missing, and also
  /// when it came back empty -- an empty list would silently hide content the
  /// user can see in the original.
  List<String> actionItemsIn(String? languageCode) {
    final translated = _usableTranslation(languageCode)?.actionItems;
    return (translated == null || translated.isEmpty)
        ? actionItems
        : translated;
  }

  List<String> highlightsIn(String? languageCode) {
    final translated = _usableTranslation(languageCode)?.highlights;
    return (translated == null || translated.isEmpty) ? highlights : translated;
  }

  List<String> topicsIn(String? languageCode) {
    final translated = _usableTranslation(languageCode)?.topics;
    return (translated == null || translated.isEmpty) ? topics : translated;
  }

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
    Map<String, String>? speakerMapping,
    String? detectedLanguage,
    Map<String, MeetingTranslation>? translations,
    Set<int>? completedActionItems,
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
      speakerMapping: speakerMapping ?? this.speakerMapping,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      translations: translations ?? this.translations,
      completedActionItems: completedActionItems ?? this.completedActionItems,
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
      speakerMapping: Map<String, String>.from(json['speakerMapping'] ?? {}),
      detectedLanguage: json['detectedLanguage'] as String?,
      // Absent on every meeting recorded before translation existed.
      translations: (json['translations'] as Map<String, dynamic>? ?? {}).map(
        (code, value) => MapEntry(
          code,
          MeetingTranslation.fromJson(value as Map<String, dynamic>),
        ),
      ),
      completedActionItems: Set<int>.from(
        json['completedActionItems'] ?? const [],
      ),
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
    'speakerMapping': speakerMapping,
    'detectedLanguage': detectedLanguage,
    'translations': translations.map((code, t) => MapEntry(code, t.toJson())),
    // Sorted so a meeting's JSON is stable across saves.
    'completedActionItems': completedActionItems.toList()..sort(),
  };

  String toJsonString() => jsonEncode(toJson());
}
