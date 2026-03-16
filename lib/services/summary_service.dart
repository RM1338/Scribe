import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MeetingSummary {
  final String summary;
  final List<String> actionItems;
  final List<String> highlights;
  final List<String> topics;
  final String? sentiment;

  const MeetingSummary({
    required this.summary,
    this.actionItems = const [],
    this.highlights = const [],
    this.topics = const [],
    this.sentiment,
  });
}

class SummaryService {
  static const String _ollamaUrl = 'http://localhost:11434/api/generate';
  static const String _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _defaultModel = 'llama3.2';
  static const String _groqModel = 'llama-3.3-70b-versatile';

  String model;
  SummaryService({this.model = _defaultModel});

  Future<bool> isAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:11434/api/tags'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<MeetingSummary> generateSummary(
    String transcript, {
    String style = 'Bullet points',
    bool detectThemes = false,
    double sensitivity = 0.5,
    String? apiKey,
    bool useCloudMode = true,
    String? transcriptLanguage,
  }) async {
    if (transcript.trim().isEmpty) {
      return const MeetingSummary(summary: 'No transcript available.');
    }

    final isCloud = useCloudMode && apiKey != null && apiKey.isNotEmpty;

    // ── Language instruction ─────────────────────────────────────────────────
    // If Whisper detected a non-English language, tell the LLM to respond
    // in the same language so summaries, action items, etc. match the source.
    final String languageInstruction;
    if (transcriptLanguage != null &&
        transcriptLanguage.isNotEmpty &&
        transcriptLanguage.toLowerCase() != 'en' &&
        transcriptLanguage.toLowerCase() != 'english') {
      languageInstruction =
          'IMPORTANT: The transcript is in language code "$transcriptLanguage". '
          'You MUST write your ENTIRE response (summary, action items, highlights, '
          'topics, sentiment — everything) in that same language. Do NOT translate to English.\n\n';
    } else {
      languageInstruction = '';
    }

    // ── Style instruction ────────────────────────────────────────────────────
    final String styleInstruction;
    switch (style.toLowerCase().trim()) {
      case 'bullet points':
        styleInstruction =
            'Provide a summary as a list of concise bullet points (each starting '
            'with "•"). Each bullet should capture one key discussion point. '
            'Aim for 3–6 bullets.';
        break;
      case 'concise summary':
      case 'executive summary':
        styleInstruction =
            'Provide a very brief executive summary in 1–2 sentences covering '
            'only the single most important outcome or decision.';
        break;
      case 'detailed narrative':
        styleInstruction =
            'Provide a detailed, cohesive narrative (3–5 sentences) that captures '
            'the full flow of the discussion, including context, key arguments, '
            'and conclusions reached.';
        break;
      default:
        styleInstruction =
            'Provide a concise summary in 2–3 sentences of what was discussed.';
    }

    // ── Action-item sensitivity ──────────────────────────────────────────────
    final String sensitivityInstruction;
    if (sensitivity < 0.3) {
      sensitivityInstruction =
          'Identify ONLY the most critical and definite action items (be very selective).';
    } else if (sensitivity > 0.7) {
      sensitivityInstruction =
          'Identify ALL possible action items, tasks, and follow-ups mentioned (be very thorough).';
    } else {
      sensitivityInstruction =
          'Identify clear and actionable items (be moderate).';
    }

    // ── Theme detection ──────────────────────────────────────────────────────
    final String themeFields = detectThemes
        ? ',\n  "topics": ["...", "..."],\n  "sentiment": "..."'
        : '';
    final String themeInstruction = detectThemes
        ? '4. A list of main topics discussed.\n'
          '5. The overall sentiment of the meeting (e.g. Positive, Neutral, Critical).\n'
        : '';

    final prompt = '''${languageInstruction}You are a professional meeting assistant. Analyze the following meeting transcript and provide:

1. Summary: $styleInstruction
2. Action items: $sensitivityInstruction
3. Key highlights or important points (decisions made, notable quotes, breakthroughs).
$themeInstruction
Respond ONLY in valid JSON — no extra text, no markdown fences:
{
  "summary": "...",
  "action_items": ["...", "..."],
  "highlights": ["...", "..."]$themeFields
}

TRANSCRIPT:
$transcript''';

    try {
      final response = await http.post(
        Uri.parse(isCloud ? _groqUrl : _ollamaUrl),
        headers: {
          'Content-Type': 'application/json',
          if (isCloud) 'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(isCloud
            ? {
                'model': _groqModel,
                'messages': [
                  {'role': 'system', 'content': 'You are a professional meeting assistant that responds ONLY in valid JSON.'},
                  {'role': 'user', 'content': prompt}
                ],
                'response_format': {'type': 'json_object'},
              }
            : {
                'model': model,
                'prompt': prompt,
                'stream': false,
                'format': 'json',
              }),
      ).timeout(const Duration(minutes: 3));

      if (response.statusCode != 200) {
        throw Exception('API error: ${response.statusCode} - ${response.body}');
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final responseText = isCloud 
          ? (responseData['choices'][0]['message']['content'] as String)
          : (responseData['response'] as String);

      final parsed = jsonDecode(responseText) as Map<String, dynamic>;

      String summaryText;
      final rawSummary = parsed['summary'];
      if (rawSummary is String) {
        summaryText = rawSummary;
      } else if (rawSummary is List) {
        summaryText = rawSummary.map((e) => e.toString()).join('\n');
      } else {
        summaryText = 'Could not generate summary.';
      }

      List<String> toStringList(dynamic value) {
        if (value is List) return value.map((e) => e.toString()).toList();
        if (value is String && value.isNotEmpty) return [value];
        return [];
      }

      return MeetingSummary(
        summary: summaryText,
        actionItems: toStringList(parsed['action_items']),
        highlights: toStringList(parsed['highlights']),
        topics: toStringList(parsed['topics']),
        sentiment: parsed['sentiment']?.toString(),
      );
    } catch (e) {
      debugPrint('SummaryService error: $e');
      return MeetingSummary(
        summary: 'Summary generation failed: ${e.toString()}',
      );
    }
  }
}
