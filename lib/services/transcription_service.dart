import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/language.dart';
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
  static const String _groqTranscribeUrl =
      'https://api.groq.com/openai/v1/audio/transcriptions';
  static const String _groqChatUrl =
      'https://api.groq.com/openai/v1/chat/completions';

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
    String? blobMime,
  }) async {
    if (!useCloudMode && !kIsWeb) {
      return _transcribeLocal(audioPath, language, diarize);
    }

    // A user-supplied key goes straight to Groq (their bill); otherwise the
    // request is proxied through the Supabase Edge Function, which holds the
    // key server-side so nothing sensitive ships in the app.
    final byok = apiKey != null && apiKey.isNotEmpty;

    final result = byok
        ? await _transcribeWhisper(
            audioPath,
            language,
            uri: Uri.parse(_groqTranscribeUrl),
            headers: {'Authorization': 'Bearer $apiKey'},
            blobMime: blobMime,
          )
        : await _transcribeWhisper(
            audioPath,
            language,
            uri: _functionUri('groq-transcribe'),
            headers: _functionHeaders(),
            blobMime: blobMime,
          );

    if (diarize && result.segments.isNotEmpty) {
      try {
        final diarized = await _diarize(result.segments, byok ? apiKey : null);
        return TranscriptionResult(
          fullText: result.fullText,
          segments: diarized,
          language: result.language,
          duration: result.duration,
        );
      } catch (_) {
        // Keep the undiarized transcript rather than failing the whole job.
      }
    }
    return result;
  }

  /// Uploads the audio to a Whisper endpoint ([uri]) and parses the verbose
  /// JSON. Works against Groq directly or the proxy -- only the target URL and
  /// auth headers differ.
  Future<TranscriptionResult> _transcribeWhisper(
    String audioPath,
    String? language, {
    required Uri uri,
    required Map<String, String> headers,
    String? blobMime,
  }) async {
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..fields['model'] = 'whisper-large-v3-turbo'
      ..fields['response_format'] = 'verbose_json';

    if (kIsWeb || audioPath.startsWith('blob:')) {
      // Web recordings live in a browser blob, not a file. Fetch the bytes
      // and label them with the MIME the recorder actually produced — Groq
      // keys its decoder off the filename extension.
      final bytes = await http.readBytes(Uri.parse(audioPath));
      final mime = blobMime ?? 'audio/webm';
      final ext = mime.contains('wav') ? 'wav' : 'webm';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'audio.$ext',
          contentType: MediaType.parse(mime),
        ),
      );
    } else {
      final file = File(audioPath);
      if (!await file.exists()) {
        throw Exception('Audio file not found: $audioPath');
      }
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          audioPath,
          contentType: MediaType('audio', 'wav'),
        ),
      );
    }

    // Omitted entirely when null, which is how Whisper is asked to auto-detect.
    final languageCode = AppLanguage.codeFor(language);
    if (languageCode != null) {
      request.fields['language'] = languageCode;
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception(
        'Transcription error: ${response.statusCode} - $responseBody',
      );
    }

    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final fullText = data['text'] as String;
    final List<dynamic> segmentsData = data['segments'] ?? [];

    final segments = segmentsData
        .map(
          (s) => MeetingSegment(
            start: (s['start'] as num).toDouble(),
            end: (s['end'] as num).toDouble(),
            text: s['text'] as String,
            speaker: null,
          ),
        )
        .toList();

    return TranscriptionResult(
      fullText: fullText,
      segments: segments,
      language: data['language'],
      duration: (data['duration'] as num?)?.toDouble(),
    );
  }

  /// Groq Whisper doesn't diarize, so we ask an LLM to label speakers from the
  /// transcript. Routes through the proxy when [apiKey] is null.
  Future<List<MeetingSegment>> _diarize(
    List<MeetingSegment> originalSegments,
    String? apiKey,
  ) async {
    final transcriptText = originalSegments
        .asMap()
        .entries
        .map((e) => '[${e.key}] ${e.value.text}')
        .join('\n');

    final prompt =
        '''You are a professional audio diarization assistant. Analyze the following transcript where each line starts with an index roughly corresponding to an audio segment. Infer the conversational flow and identify the speaker for each segment (e.g. "Speaker A", "Speaker B", etc.).
Respond ONLY in valid JSON conforming to this structure:
{
  "diarization": [
    {"index": 0, "speaker": "Speaker A"},
    {"index": 1, "speaker": "Speaker B"}
  ]
}

TRANSCRIPT:
$transcriptText''';

    final data = await _chatCompletion({
      'model': 'llama-3.3-70b-versatile',
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a professional audio diarization assistant that responds ONLY in valid JSON.',
        },
        {'role': 'user', 'content': prompt},
      ],
      'response_format': {'type': 'json_object'},
    }, apiKey);

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

  /// POSTs a chat-completion [body] to Groq directly (when [apiKey] is set) or
  /// to the Supabase proxy, returning the decoded JSON response.
  Future<Map<String, dynamic>> _chatCompletion(
    Map<String, dynamic> body,
    String? apiKey,
  ) async {
    final byok = apiKey != null && apiKey.isNotEmpty;
    final uri = byok ? Uri.parse(_groqChatUrl) : _functionUri('groq-chat');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (byok) 'Authorization': 'Bearer $apiKey' else ..._functionHeaders(),
    };

    final response = await http
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(minutes: 1));

    if (response.statusCode != 200) {
      throw Exception(
        'Chat completion error: ${response.statusCode} - ${response.body}',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  /// URL of a deployed Edge Function, built from the Supabase project URL.
  Uri _functionUri(String name) {
    final base = dotenv.env['SUPABASE_URL'];
    if (base == null || base.isEmpty) {
      throw Exception('SUPABASE_URL is not set; cannot reach the AI proxy.');
    }
    return Uri.parse('$base/functions/v1/$name');
  }

  /// Auth for a proxy call: the signed-in user's JWT gates access (the function
  /// rejects anonymous callers), with the anon key as the required apikey.
  Map<String, String> _functionHeaders() {
    final anon = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    final token =
        Supabase.instance.client.auth.currentSession?.accessToken ?? anon;
    return {'Authorization': 'Bearer $token', 'apikey': anon};
  }

  Future<TranscriptionResult> _transcribeLocal(
    String audioPath,
    String? language,
    bool diarize,
  ) async {
    // Legacy local server implementation
    final response = await http
        .post(
          Uri.parse('http://127.0.0.1:$_port/transcribe'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'audio_path': audioPath,
            'language': language,
            'diarize': diarize,
          }),
        )
        .timeout(const Duration(minutes: 5));

    if (response.statusCode != 200) {
      throw Exception('Local server error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return TranscriptionResult(
      fullText: data['full_text'],
      segments: (data['segments'] as List)
          .map((s) => MeetingSegment.fromJson(s))
          .toList(),
      language: data['language'],
      duration: data['duration'],
    );
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
