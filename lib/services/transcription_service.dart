import 'dart:convert';
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import '../models/meeting.dart';
import 'package:http/http.dart' as http;

class TranscriptionResult {
  final String fullText;
  final List<MeetingSegment> segments;
  final String? language;
  final double? duration;

  TranscriptionResult({
    required this.fullText,
    required this.segments,
    this.language,
    this.duration,
  });
}

class TranscriptionService {
  static const String _groqUrl = 'https://api.groq.com/openai/v1/audio/transcriptions';
  
  // Local server constants (legacy, keeping for reference if user toggles cloud off)
  static const int _port = 8765;
  Process? _serverProcess;

  TranscriptionService();

  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String? language,
    bool diarize = false,
    String? apiKey,
    bool useCloudMode = true,
  }) async {
    if (useCloudMode && apiKey != null && apiKey.isNotEmpty) {
      return _transcribeCloud(audioPath, apiKey, language, diarize);
    } else {
      return _transcribeLocal(audioPath, language, diarize);
    }
  }

  Future<TranscriptionResult> _transcribeCloud(String audioPath, String apiKey, String? language, bool diarize) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      throw Exception('Audio file not found: $audioPath');
    }

    final request = http.MultipartRequest('POST', Uri.parse(_groqUrl))
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..fields['model'] = 'whisper-large-v3-turbo'
      ..fields['response_format'] = 'verbose_json'
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        audioPath,
        contentType: MediaType('audio', 'wav'), // Fixed: record package uses wav
      ));

    if (language != null && language != 'Auto-detect') {
      request.fields['language'] = _mapLanguageToCode(language);
    }

    // Groq Whisper doesn't support speaker diarization natively yet.
    // We will use a basic time-based heuristic here until a better diarizer is added.
    
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Groq error: ${response.statusCode} - $responseBody');
    }

    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final fullText = data['text'] as String;
    final List<dynamic> segmentsData = data['segments'] ?? [];

    var segments = segmentsData.map((s) => MeetingSegment(
      start: (s['start'] as num).toDouble(),
      end: (s['end'] as num).toDouble(),
      text: s['text'] as String,
      speaker: null, // Cloud Whisper doesn't diarize yet
    )).toList();

    if (diarize && segments.isNotEmpty) {
      try {
        segments = await _diarizeCloud(segments, apiKey);
      } catch (e) {
        // Silently ignore diarization failures to ensure transcription still returns
      }
    }

    return TranscriptionResult(
      fullText: fullText,
      segments: segments,
      language: data['language'],
      duration: (data['duration'] as num?)?.toDouble(),
    );
  }

  Future<TranscriptionResult> _transcribeLocal(String audioPath, String? language, bool diarize) async {
    // Legacy local server implementation
    final response = await http.post(
      Uri.parse('http://127.0.0.1:$_port/transcribe'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'audio_path': audioPath,
        'language': language,
        'diarize': diarize,
      }),
    ).timeout(const Duration(minutes: 5));

    if (response.statusCode != 200) {
      throw Exception('Local server error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return TranscriptionResult(
      fullText: data['full_text'],
      segments: (data['segments'] as List).map((s) => MeetingSegment.fromJson(s)).toList(),
      language: data['language'],
      duration: data['duration'],
    );
  }

  Future<List<MeetingSegment>> _diarizeCloud(List<MeetingSegment> originalSegments, String apiKey) async {
    final transcriptText = originalSegments
        .asMap()
        .entries
        .map((e) => '[${e.key}] ${e.value.text}')
        .join('\n');

    final prompt = '''You are a professional audio diarization assistant. Analyze the following transcript where each line starts with an index roughly corresponding to an audio segment. Infer the conversational flow and identify the speaker for each segment (e.g. "Speaker A", "Speaker B", etc.).
Respond ONLY in valid JSON conforming to this structure:
{
  "diarization": [
    {"index": 0, "speaker": "Speaker A"},
    {"index": 1, "speaker": "Speaker B"}
  ]
}

TRANSCRIPT:
$transcriptText''';

    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {'role': 'system', 'content': 'You are a professional audio diarization assistant that responds ONLY in valid JSON.'},
          {'role': 'user', 'content': prompt}
        ],
        'response_format': {'type': 'json_object'},
      }),
    ).timeout(const Duration(minutes: 1));

    if (response.statusCode != 200) {
      return originalSegments;
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'] as String;
    final parsed = jsonDecode(content);
    
    final diarizationList = parsed['diarization'] as List<dynamic>?;
    if (diarizationList == null) return originalSegments;

    final speakerMap = <int, String>{};
    for (final item in diarizationList) {
      if (item is Map<String, dynamic>) {
        final index = item['index'];
        final speaker = item['speaker'];
        if (index is int && speaker is String) {
          speakerMap[index] = speaker;
        }
      }
    }

    return originalSegments.asMap().entries.map((e) {
      return MeetingSegment(
        start: e.value.start,
        end: e.value.end,
        text: e.value.text,
        speaker: speakerMap[e.key] ?? e.value.speaker,
      );
    }).toList();
  }

  String _mapLanguageToCode(String language) {
    switch (language) {
      case 'English': return 'en';
      case 'Spanish': return 'es';
      case 'French': return 'fr';
      case 'German': return 'de';
      default: return 'en';
    }
  }

  // Lifecycle methods for local server (optional now)
  Future<void> startServer({String model = 'small'}) async {
    // Keep internal for backward compatibility if logic exists elsewhere
  }

  Future<void> stopServer() async {
    _serverProcess?.kill();
    _serverProcess = null;
  }
}
