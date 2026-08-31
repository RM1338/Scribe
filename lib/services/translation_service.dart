import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/language.dart';
import '../models/meeting.dart';

class TranslationException implements Exception {
  final String message;
  const TranslationException(this.message);
  @override
  String toString() => message;
}

/// Translates an already-transcribed meeting into another language.
///
/// This works on stored text, never on the audio. Groq does expose an
/// `/audio/translations` endpoint, but it only ever outputs English and only on
/// `whisper-large-v3` -- useless for translating into an arbitrary target. So
/// we re-use the same chat model the summariser uses.
///
/// Segments are translated in place, positionally: the model is handed a JSON
/// object of `index -> source text` and must return the same indices. That
/// preserves the 1:1 alignment with [Meeting.segments] that the player's
/// seek-and-highlight depends on.
class TranslationService {
  static const String _groqUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _groqModel = 'openai/gpt-oss-120b';

  /// Segments per request. Large enough to give the model surrounding context
  /// (so pronouns and terminology stay consistent), small enough that the
  /// response cannot run past the output token limit and get truncated.
  static const int _batchSize = 30;

  static const Duration _timeout = Duration(minutes: 2);

  final http.Client _http;

  TranslationService({http.Client? client}) : _http = client ?? http.Client();

  /// Translates [meeting]'s segments and, if present, its summary, action
  /// items, highlights and topics.
  ///
  /// [onProgress] reports 0.0-1.0 so the UI can show real progress across what
  /// may be a dozen sequential requests.
  Future<MeetingTranslation> translateMeeting(
    Meeting meeting, {
    required String targetLanguageCode,
    required String apiKey,
    void Function(double progress)? onProgress,
  }) async {
    if (apiKey.isEmpty) {
      throw const TranslationException(
        'Add your Groq API key in Settings to translate meetings.',
      );
    }
    if (meeting.segments.isEmpty) {
      throw const TranslationException(
        'This meeting has no transcript to translate.',
      );
    }

    final target = AppLanguage.byCode(targetLanguageCode);
    if (target == null) {
      throw TranslationException('Unsupported language: $targetLanguageCode');
    }

    final batches = <List<int>>[];
    for (var i = 0; i < meeting.segments.length; i += _batchSize) {
      final end = (i + _batchSize).clamp(0, meeting.segments.length);
      batches.add([for (var j = i; j < end; j++) j]);
    }

    // One extra unit of work for the summary pass, when there is one.
    final hasSummaryWork =
        (meeting.summary?.trim().isNotEmpty ?? false) ||
        meeting.actionItems.isNotEmpty ||
        meeting.highlights.isNotEmpty ||
        meeting.topics.isNotEmpty;
    final totalUnits = batches.length + (hasSummaryWork ? 1 : 0);
    var completedUnits = 0;

    final translatedSegments = List<String>.filled(meeting.segments.length, '');

    for (final batch in batches) {
      final source = {
        for (final i in batch) i.toString(): meeting.segments[i].text.trim(),
      };
      final translated = await _translateMap(source, target, apiKey);

      for (final i in batch) {
        // A model that drops an index leaves the original text in place rather
        // than a blank line. Better a stray untranslated sentence than a hole.
        translatedSegments[i] =
            translated[i.toString()] ?? meeting.segments[i].text.trim();
      }

      completedUnits++;
      onProgress?.call(completedUnits / totalUnits);
    }

    String? translatedSummary;
    var translatedActionItems = <String>[];
    var translatedHighlights = <String>[];
    var translatedTopics = <String>[];

    if (hasSummaryWork) {
      final source = <String, String>{
        if (meeting.summary?.trim().isNotEmpty ?? false)
          'summary': meeting.summary!.trim(),
        for (var i = 0; i < meeting.actionItems.length; i++)
          'action_$i': meeting.actionItems[i],
        for (var i = 0; i < meeting.highlights.length; i++)
          'highlight_$i': meeting.highlights[i],
        for (var i = 0; i < meeting.topics.length; i++)
          'topic_$i': meeting.topics[i],
      };

      final translated = await _translateMap(source, target, apiKey);

      translatedSummary = translated['summary'] ?? meeting.summary;
      translatedActionItems = [
        for (var i = 0; i < meeting.actionItems.length; i++)
          translated['action_$i'] ?? meeting.actionItems[i],
      ];
      translatedHighlights = [
        for (var i = 0; i < meeting.highlights.length; i++)
          translated['highlight_$i'] ?? meeting.highlights[i],
      ];
      translatedTopics = [
        for (var i = 0; i < meeting.topics.length; i++)
          translated['topic_$i'] ?? meeting.topics[i],
      ];

      completedUnits++;
      onProgress?.call(completedUnits / totalUnits);
    }

    return MeetingTranslation(
      languageCode: target.code,
      segmentTexts: translatedSegments,
      summary: translatedSummary,
      actionItems: translatedActionItems,
      highlights: translatedHighlights,
      topics: translatedTopics,
      translatedAt: DateTime.now(),
    );
  }

  /// Sends `{key: sourceText}` and expects `{key: translatedText}` back with
  /// every key preserved. Keys are opaque to the model, which is what stops it
  /// merging or reordering lines.
  Future<Map<String, String>> _translateMap(
    Map<String, String> source,
    AppLanguage target,
    String apiKey,
  ) async {
    final systemPrompt =
        'You are a professional translator. You translate meeting transcripts into '
        '${target.name} (${target.nativeName}).\n'
        'You will receive a JSON object mapping opaque keys to source text.\n'
        'Rules:\n'
        '1. Return a JSON object with EXACTLY the same keys. Never add, drop, merge, '
        'reorder or renumber keys.\n'
        '2. Translate only the values, into ${target.name}.\n'
        '3. Each value is one line of a spoken transcript. Translate it as a whole '
        'utterance; do not split or join lines even if a sentence spans several.\n'
        '4. Preserve proper nouns, product names, numbers and acronyms as-is.\n'
        '5. If a value is already in ${target.name}, return it unchanged.\n'
        '6. Never add commentary, notes or explanations.';

    final response = await _http
        .post(
          Uri.parse(_groqUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': _groqModel,
            'temperature': 0.2, // Translation wants fidelity, not invention.
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': jsonEncode(source)},
            ],
            'response_format': {'type': 'json_object'},
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 401) {
      throw const TranslationException(
        'Your Groq API key was rejected. Check it in Settings.',
      );
    }
    if (response.statusCode == 429) {
      throw const TranslationException(
        'Groq rate limit reached. Wait a moment and try again.',
      );
    }
    if (response.statusCode != 200) {
      throw TranslationException(
        'Translation failed (${response.statusCode}).',
      );
    }

    // Groq returns UTF-8; response.body decodes as latin-1 and would mangle
    // every non-Latin script we just asked for.
    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final content = decoded['choices']?[0]?['message']?['content'] as String?;
    if (content == null) {
      throw const TranslationException(
        'Translation service returned an empty response.',
      );
    }

    final parsed = jsonDecode(content);
    if (parsed is! Map<String, dynamic>) {
      throw const TranslationException(
        'Translation service returned an unexpected format.',
      );
    }

    return parsed.map((key, value) => MapEntry(key, value?.toString() ?? ''));
  }

  void dispose() => _http.close();
}
