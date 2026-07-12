import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/meeting.dart';
import '../models/folder.dart';
import '../models/scheduled_meeting.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/transcription_service.dart';
import '../services/summary_service.dart';
import '../services/translation_service.dart';
import 'settings_provider.dart';

enum RecordingState { idle, recording, paused }

enum ProcessingState { idle, transcribing, summarizing }

class MeetingProvider with ChangeNotifier {
  StorageService _storage = StorageService();
  String? _userId;
  final TranscriptionService _transcription = TranscriptionService();
  final SummaryService _summary = SummaryService();
  final TranslationService _translation = TranslationService();
  final AudioRecorder _recorder = AudioRecorder();
  final SpeechToText _speechToText = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _timer;
  SettingsProvider? _settings;

  List<Meeting> _meetings = [];
  List<Folder> _folders = [];
  List<ScheduledMeeting> _scheduledMeetings = [];
  List<String> _recentSearches = [];
  String _selectedFilter = 'All';
  String? _selectedFolderId;
  bool _initialized = false;
  RecordingState _recordingState = RecordingState.idle;
  ProcessingState _processingState = ProcessingState.idle;
  Duration _recordingDuration = Duration.zero;
  String _liveTranscriptBuffer = '';
  String _currentLiveWords = '';
  String? _currentProcessingId;
  String? _ollamaStatus; // null = not checked, 'ok', 'unavailable'

  /// Meeting id currently being translated, and how far along it is. Only one
  /// translation runs at a time -- they are long, and they contend for the same
  /// Groq rate limit as transcription.
  String? _translatingMeetingId;
  double _translationProgress = 0;
  String? _translationError;
  final _notificationController = StreamController<String>.broadcast();

  // Advanced Search Filters
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  final List<String> _filterSpeakers = [];
  final List<String> _filterTags = [];
  String? _filterSentiment;
  bool _filterActionItemsOnly = false;

  // Playback state
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  Duration _totalDuration = Duration.zero;
  String? _currentlyPlayingId;

  /// Playback position, deliberately kept off [notifyListeners].
  ///
  /// The player emits a position roughly five times a second. Routing that
  /// through the provider's own listeners would rebuild every [Consumer] in the
  /// tree -- including whole screens -- at that rate. Widgets that actually care
  /// about the playhead (scrubbers, the synced transcript) subscribe to this
  /// notifier instead, so the rebuild stays scoped to them.
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);

  final List<String> filters = [
    'All',
    'Transcribed',
    'In Progress',
    'Favorites',
  ];

  MeetingProvider() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });
    // ValueNotifier suppresses a notification when the value is unchanged, so a
    // paused player costs nothing here.
    _audioPlayer.onPositionChanged.listen((pos) => position.value = pos);
    _audioPlayer.onDurationChanged.listen((dur) {
      _totalDuration = dur;
      notifyListeners();
    });
  }

  // ── Getters ───────────────────────────────────────────────
  List<Meeting> get meetings {
    List<Meeting> filtered = List.from(_meetings);

    if (_selectedFolderId != null) {
      filtered = filtered
          .where((m) => m.folderIds.contains(_selectedFolderId))
          .toList();
    }

    switch (_selectedFilter) {
      case 'Transcribed':
        return filtered
            .where((m) => !m.isNote && m.status == MeetingStatus.transcribed)
            .toList();
      case 'In Progress':
        return filtered
            .where(
              (m) =>
                  !m.isNote &&
                  (m.status == MeetingStatus.inProgress ||
                      m.status == MeetingStatus.processing),
            )
            .toList();
      case 'Favorites':
        return filtered.where((m) => m.isFavorite).toList();
      default:
        return filtered;
    }
  }

  List<Meeting> get allMeetings => List.from(_meetings);
  List<Folder> get folders => List.from(_folders);
  List<String> get recentSearches => List.from(_recentSearches);
  String? get selectedFolderId => _selectedFolderId;

  String get selectedFilter => _selectedFilter;
  RecordingState get recordingState => _recordingState;
  ProcessingState get processingState => _processingState;
  Duration get recordingDuration => _recordingDuration;
  String get liveTranscript {
    final combined = '$_liveTranscriptBuffer$_currentLiveWords'.trim();
    return combined.isEmpty ? '' : combined;
  }

  Stream<String> get notificationStream => _notificationController.stream;
  String? get currentProcessingId => _currentProcessingId;

  bool isTranslating(String meetingId) => _translatingMeetingId == meetingId;
  double get translationProgress => _translationProgress;
  String? get translationError => _translationError;

  void clearTranslationError() {
    if (_translationError == null) return;
    _translationError = null;
    notifyListeners();
  }

  /// Ticks or un-ticks the action item at [index]. Persisted immediately -- a
  /// checklist that forgets on relaunch is worse than no checklist.
  Future<void> toggleActionItem(String meetingId, int index) async {
    final position = _meetings.indexWhere((m) => m.id == meetingId);
    if (position == -1) return;

    final meeting = _meetings[position];
    if (index < 0 || index >= meeting.actionItems.length) return;

    final completed = Set<int>.from(meeting.completedActionItems);
    if (!completed.remove(index)) completed.add(index);

    _meetings[position] = meeting.copyWith(completedActionItems: completed);
    notifyListeners();
    await _storage.saveMeetings(_meetings);
  }

  /// Translates [meetingId] into [languageCode] and caches the result on the
  /// meeting. A no-op when a usable translation already exists, so re-opening a
  /// translated transcript costs nothing.
  ///
  /// Returns true if a translation is available afterwards.
  Future<bool> translateMeeting(String meetingId, String languageCode) async {
    final index = _meetings.indexWhere((m) => m.id == meetingId);
    if (index == -1) return false;

    if (_meetings[index].hasTranslation(languageCode)) return true;
    if (_translatingMeetingId != null) return false;

    _translatingMeetingId = meetingId;
    _translationProgress = 0;
    _translationError = null;
    notifyListeners();

    try {
      final translation = await _translation.translateMeeting(
        _meetings[index],
        targetLanguageCode: languageCode,
        apiKey: _settings?.groqApiKey ?? '',
        onProgress: (p) {
          _translationProgress = p;
          notifyListeners();
        },
      );

      // Re-resolve: the list may have been reloaded or reordered while the
      // network call was in flight.
      final current = _meetings.indexWhere((m) => m.id == meetingId);
      if (current == -1) return false;

      _meetings[current] = _meetings[current].copyWith(
        translations: {
          ..._meetings[current].translations,
          languageCode: translation,
        },
      );
      await _storage.saveMeetings(_meetings);
      return true;
    } on TranslationException catch (e) {
      _translationError = e.message;
      return false;
    } catch (e) {
      _translationError =
          'Translation failed. Check your connection and try again.';
      return false;
    } finally {
      _translatingMeetingId = null;
      _translationProgress = 0;
      notifyListeners();
    }
  }

  bool get isOllamaAvailable => _ollamaStatus == 'ok';

  Meeting? get currentlyPlayingMeeting {
    if (_currentlyPlayingId == null) return null;
    try {
      return _meetings.firstWhere((m) => m.id == _currentlyPlayingId);
    } catch (_) {
      return null;
    }
  }

  bool get isPlaying => _isPlaying;
  double get playbackSpeed => _playbackSpeed;
  Duration get playbackPosition => position.value;
  Duration get totalDuration => _totalDuration;
  String? get currentlyPlayingId => _currentlyPlayingId;

  // Advanced Search Filter Getters
  DateTime? get filterStartDate => _filterStartDate;
  DateTime? get filterEndDate => _filterEndDate;
  List<String> get filterSpeakers => _filterSpeakers;
  List<String> get filterTags => _filterTags;
  String? get filterSentiment => _filterSentiment;
  bool get filterActionItemsOnly => _filterActionItemsOnly;

  // Smart Categories
  List<Meeting> get actionOrientedMeetings =>
      _meetings.where((m) => m.actionItems.isNotEmpty).toList();
  List<Meeting> get highlightMeetings =>
      _meetings.where((m) => m.highlights.isNotEmpty).toList();
  List<Meeting> get shortMeetings => _meetings.where((m) {
    if (m.isNote) return false; // Notes have no duration to reason about.
    // Duration is usually "Mm Ss" or "Ss".
    // Simple approximation: check if "h" or > 5m
    if (m.duration.contains('h')) return false;
    final mMatch = RegExp(r'(\d+)m').firstMatch(m.duration);
    if (mMatch != null) {
      final minutes = int.parse(mMatch.group(1)!);
      return minutes < 5;
    }
    return true; // Just seconds
  }).toList();

  List<String> get uniqueTeams => _meetings.map((m) => m.team).toSet().toList();
  List<String> get uniqueSpeakers =>
      _meetings.expand((m) => m.speakers).toSet().toList();
  List<String> get uniqueTags =>
      _meetings.expand((m) => m.tags).toSet().toList();

  // ── Initialisation ───────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    _meetings = await _storage.loadMeetings();

    final folderData = await _storage.loadFolders();
    _folders = folderData.map((e) => Folder.fromJson(e)).toList();
    final scheduledData = await _storage.loadScheduledMeetings();
    _scheduledMeetings = scheduledData
        .map((e) => ScheduledMeeting.fromJson(e as Map<String, dynamic>))
        .toList();
    _recentSearches = await _storage.loadRecentSearches();
    _initialized = true;
    notifyListeners();

    // Initialize speech to text early
    _initSpeechToText();

    // Check Ollama (for fallback/local mode) in background
    _summary.isAvailable().then((ok) {
      _ollamaStatus = ok ? 'ok' : 'unavailable';
      notifyListeners();
    });
  }

  void attachSettings(SettingsProvider settings) {
    _settings = settings;
    notifyListeners();
  }

  /// Rebinds this provider to [userId], loading that account's data.
  ///
  /// Called whenever the signed-in user changes -- including sign-out, where
  /// [userId] is null. In-memory collections are cleared before the reload so
  /// the previous account's meetings can never be observed by the next one,
  /// even for the moment between sign-in and the first disk read completing.
  void setUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;

    _meetings = [];
    _folders = [];
    _scheduledMeetings = [];
    _recentSearches = [];
    _selectedFilter = 'All';
    _selectedFolderId = null;
    _initialized = false;
    _storage = StorageService(userId: userId);

    // This runs from ChangeNotifierProxyProvider.update, i.e. during build,
    // where notifying listeners synchronously would throw. Defer both the
    // notification and the reload to after the current frame.
    scheduleMicrotask(() async {
      notifyListeners();
      if (userId != null) {
        await _storage.migrateLegacyData();
        await init();
      }
    });
  }

  // ── Filter ───────────────────────────────────────────────
  void setFilter(String filter) {
    if (filters.contains(filter)) {
      _selectedFilter = filter;
      _selectedFolderId =
          null; // Clear folder filter when changing global filter
      notifyListeners();
    }
  }

  void setFolder(String? folderId) {
    _selectedFolderId = folderId;
    _selectedFilter = 'All'; // Reset global filter when selecting a folder
    notifyListeners();
  }

  // ── Folders ──────────────────────────────────────────────
  /// Creates a folder and returns its id, so callers (e.g. the "Move to
  /// Folder" dialog) can select the meeting into it right away.
  Future<String> createFolder(String name, int colorValue) async {
    final folder = Folder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      colorValue: colorValue,
    );
    _folders.add(folder);
    await _storage.saveFolders(_folders.map((f) => f.toJson()).toList());
    notifyListeners();
    return folder.id;
  }

  Future<void> deleteFolder(String folderId) async {
    _folders.removeWhere((f) => f.id == folderId);
    // Drop this folder from every meeting that referenced it.
    _meetings = _meetings.map((m) {
      if (m.folderIds.contains(folderId)) {
        return m.copyWith(
          folderIds: m.folderIds.where((id) => id != folderId).toList(),
        );
      }
      return m;
    }).toList();
    await _storage.saveFolders(_folders.map((f) => f.toJson()).toList());
    await _storage.saveMeetings(_meetings);
    if (_selectedFolderId == folderId) _selectedFolderId = null;
    notifyListeners();
  }

  /// Replaces the full set of folders a meeting belongs to -- used by the
  /// multi-select "Move to Folder" dialog. Ignores ids for folders that no
  /// longer exist.
  Future<void> setMeetingFolders(
    String meetingId,
    List<String> folderIds,
  ) async {
    final index = _meetings.indexWhere((m) => m.id == meetingId);
    if (index == -1) return;
    final valid = folderIds
        .where((id) => _folders.any((f) => f.id == id))
        .toList();
    _meetings[index] = _meetings[index].copyWith(folderIds: valid);
    await _storage.saveMeetings(_meetings);
    notifyListeners();
  }

  /// Removes a single meeting from a single folder, leaving its other folders
  /// intact. Used by the swipe/menu action in the Folders tab.
  Future<void> removeMeetingFromFolder(
    String meetingId,
    String folderId,
  ) async {
    final index = _meetings.indexWhere((m) => m.id == meetingId);
    if (index == -1) return;
    final m = _meetings[index];
    if (!m.folderIds.contains(folderId)) return;
    _meetings[index] = m.copyWith(
      folderIds: m.folderIds.where((id) => id != folderId).toList(),
    );
    await _storage.saveMeetings(_meetings);
    notifyListeners();
  }

  // ── Scheduled meetings (stored in-app, not the device calendar) ──────────
  List<ScheduledMeeting> get scheduledMeetings =>
      List.from(_scheduledMeetings);

  /// Scheduled meetings that fall on [day], earliest first.
  List<ScheduledMeeting> scheduledMeetingsOn(DateTime day) {
    final result =
        _scheduledMeetings
            .where(
              (s) =>
                  s.start.year == day.year &&
                  s.start.month == day.month &&
                  s.start.day == day.day,
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  Future<void> addScheduledMeeting(
    String title,
    DateTime start, {
    int durationMinutes = 60,
    String? description,
  }) async {
    final scheduled = ScheduledMeeting(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      start: start,
      durationMinutes: durationMinutes,
    );
    _scheduledMeetings.add(scheduled);
    await _storage.saveScheduledMeetings(
      _scheduledMeetings.map((s) => s.toJson()).toList(),
    );
    // Fire-and-forget the reminder; storage is the source of truth.
    NotificationService.scheduleMeetingReminder(scheduled);
    notifyListeners();
  }

  Future<void> deleteScheduledMeeting(String id) async {
    _scheduledMeetings.removeWhere((s) => s.id == id);
    await _storage.saveScheduledMeetings(
      _scheduledMeetings.map((s) => s.toJson()).toList(),
    );
    NotificationService.cancelMeetingReminder(id);
    notifyListeners();
  }

  // ── Search History ───────────────────────────────────────
  Future<void> addRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    _recentSearches.remove(q);
    _recentSearches.insert(0, q);
    if (_recentSearches.length > 10)
      _recentSearches = _recentSearches.sublist(0, 10);

    await _storage.saveRecentSearches(_recentSearches);
    notifyListeners();
  }

  Future<void> clearRecentSearches() async {
    _recentSearches.clear();
    await _storage.saveRecentSearches(_recentSearches);
    notifyListeners();
  }

  // ── Advanced Filtering ────────────────────────────────────
  void setDateRange(DateTime? start, DateTime? end) {
    _filterStartDate = start;
    _filterEndDate = end;
    notifyListeners();
  }

  void toggleSpeakerFilter(String speaker) {
    if (_filterSpeakers.contains(speaker)) {
      _filterSpeakers.remove(speaker);
    } else {
      _filterSpeakers.add(speaker);
    }
    notifyListeners();
  }

  void toggleTagFilter(String tag) {
    if (_filterTags.contains(tag)) {
      _filterTags.remove(tag);
    } else {
      _filterTags.add(tag);
    }
    notifyListeners();
  }

  void setSentimentFilter(String? sentiment) {
    _filterSentiment = sentiment;
    notifyListeners();
  }

  void setActionItemsOnly(bool only) {
    _filterActionItemsOnly = only;
    notifyListeners();
  }

  void clearAllFilters() {
    _filterStartDate = null;
    _filterEndDate = null;
    _filterSpeakers.clear();
    _filterTags.clear();
    _filterSentiment = null;
    _filterActionItemsOnly = false;
    notifyListeners();
  }

  List<Meeting> searchMeetings(String query) {
    final lowerQuery = query.toLowerCase();

    // Parse shorthand @speaker and #tag
    final speakerTokens = RegExp(
      r'@(\w+)',
    ).allMatches(lowerQuery).map((m) => m.group(1)!.toLowerCase()).toList();
    final tagTokens = RegExp(
      r'#([\w-]+)',
    ).allMatches(lowerQuery).map((m) => m.group(1)!.toLowerCase()).toList();

    // Remove tokens from search query text
    String cleanQuery = lowerQuery
        .replaceAll(RegExp(r'@\w+'), '')
        .replaceAll(RegExp(r'#[\w-]+'), '')
        .trim();

    return _meetings.where((m) {
      // 1. Text Search (title, transcript, summary, topics)
      if (cleanQuery.isNotEmpty) {
        bool match =
            m.title.toLowerCase().contains(cleanQuery) ||
            (m.transcript?.toLowerCase().contains(cleanQuery) ?? false) ||
            (m.summary?.toLowerCase().contains(cleanQuery) ?? false) ||
            (m.notes?.toLowerCase().contains(cleanQuery) ?? false) ||
            m.topics.any((t) => t.toLowerCase().contains(cleanQuery));
        if (!match) return false;
      }

      // 2. Speaker Shorthand & Filter
      if (speakerTokens.isNotEmpty) {
        bool match = speakerTokens.every(
          (token) =>
              m.speakers.any((s) => s.toLowerCase().contains(token)) ||
              m.attendeeInitials.any((i) => i.toLowerCase() == token),
        );
        if (!match) return false;
      }
      if (_filterSpeakers.isNotEmpty) {
        if (!_filterSpeakers.any((s) => m.speakers.contains(s))) return false;
      }

      // 3. Tag Shorthand & Filter
      if (tagTokens.isNotEmpty) {
        bool match = tagTokens.every(
          (token) => m.tags.any((t) => t.toLowerCase() == token),
        );
        if (!match) return false;
      }
      if (_filterTags.isNotEmpty) {
        if (!_filterTags.any((t) => m.tags.contains(t))) return false;
      }

      // 4. Date Range Filter
      if (_filterStartDate != null && m.recordedAt != null) {
        if (m.recordedAt!.isBefore(_filterStartDate!)) return false;
      }
      if (_filterEndDate != null && m.recordedAt != null) {
        if (m.recordedAt!.isAfter(_filterEndDate!)) return false;
      }

      // 5. Action Items Only
      if (_filterActionItemsOnly && m.actionItems.isEmpty) return false;

      // 6. Sentiment
      if (_filterSentiment != null && m.sentiment != _filterSentiment)
        return false;

      return true;
    }).toList();
  }

  // ── Recording ────────────────────────────────────────────
  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    // Reset timer for new recording
    _recordingDuration = Duration.zero;
    notifyListeners();

    final recordingsDir = await _storage.recordingsDir();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final path = p.join(recordingsDir.path, '$id.wav');

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        // Reverting to mic, but keeping AndroidRecordConfig for potential further tweaks
        androidConfig: const AndroidRecordConfig(
          audioSource: AndroidAudioSource.mic,
        ),
        device:
            _settings?.audioSourceId != null &&
                _settings!.audioSourceId.isNotEmpty
            ? InputDevice(id: _settings!.audioSourceId, label: '')
            : null,
      ),
      path: path,
    );

    _recordingState = RecordingState.recording;
    _liveTranscriptBuffer = '';
    _currentLiveWords = '';
    notifyListeners();

    // NOTE: SpeechToText is NOT started during recording because on Android,
    // AudioRecorder and SpeechToText both compete for exclusive audio focus.
    // SpeechToText always loses, resulting in error_speech_timeout (Error 7)
    // with rmsDB = -2.0 (no audio input). Full transcription happens
    // post-recording via the Groq Whisper API instead.

    // Start tick timer
    _startTimer();
  }

  Future<void> _initSpeechToText() async {
    try {
      await _speechToText.initialize(
        debugLogging: false,
        onStatus: (status) {
          debugPrint('SpeechToText status: $status');
          // Do NOT auto-restart during recording — SpeechToText cannot
          // coexist with AudioRecorder on Android (audio focus conflict).
        },
        onError: (error) {
          debugPrint('SpeechToText error: $error');
        },
      );
    } catch (e) {
      debugPrint('SpeechToText init error: $e');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_recordingState == RecordingState.recording) {
        _recordingDuration += const Duration(seconds: 1);
        notifyListeners();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> pauseRecording() async {
    await _recorder.pause();
    _stopTimer();
    _recordingState = RecordingState.paused;
    notifyListeners();
  }

  Future<void> resumeRecording() async {
    await _recorder.resume();
    _recordingState = RecordingState.recording;
    _startTimer();
    notifyListeners();
  }

  Future<String?> stopRecording() async {
    _stopTimer();
    final path = await _recorder.stop();
    debugPrint('Recorder stopped. Path: $path');
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        debugPrint('Recorded file size: $size bytes');
      } else {
        debugPrint('Recorded file DOES NOT EXIST at $path');
      }
    }
    _recordingState = RecordingState.idle;
    notifyListeners();
    return path;
  }

  // ── Playback ─────────────────────────────────────────────
  Future<void> playMeeting(Meeting meeting) async {
    if (meeting.audioFilePath == null) return;

    final file = File(meeting.audioFilePath!);
    if (!await file.exists()) {
      _notificationController.add(
        'Audio file not found at ${meeting.audioFilePath}',
      );
      return;
    }

    try {
      if (_currentlyPlayingId == meeting.id) {
        if (_isPlaying) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.resume();
        }
      } else {
        await _audioPlayer.stop();
        _currentlyPlayingId = meeting.id;
        // The new track starts at zero; without this the transcript would keep
        // highlighting wherever the previous one left off until the first tick.
        position.value = Duration.zero;
        _totalDuration = Duration.zero;
        await _audioPlayer.setPlaybackRate(_playbackSpeed);
        await _audioPlayer.play(DeviceFileSource(meeting.audioFilePath!));
      }
    } catch (e) {
      debugPrint('AudioPlayer error: $e');
      _notificationController.add('Failed to play audio: ${e.toString()}');
      _isPlaying = false;
      _currentlyPlayingId = null;
      position.value = Duration.zero;
    }
    notifyListeners();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    if (_currentlyPlayingId != null) {
      await _audioPlayer.setPlaybackRate(speed);
    }
    notifyListeners();
  }

  Future<void> stopAudio() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    _currentlyPlayingId = null;
    position.value = Duration.zero;
    notifyListeners();
  }

  // ── Create & Transcribe ──────────────────────────────────
  Future<Meeting> createMeetingFromRecording(
    String audioPath, {
    String? title,
    Duration? duration,
  }) async {
    final now = DateTime.now();
    final id = now.millisecondsSinceEpoch.toString();
    final actualDuration = (duration != null && duration != Duration.zero)
        ? duration
        : _recordingDuration;
    final durationStr = _formatDuration(actualDuration);

    final meeting = Meeting(
      id: id,
      title: title ?? 'Meeting ${_formatDateTitle(now)}',
      team: 'Personal',
      date: _formatDate(now),
      duration: durationStr,
      status: (_settings?.isAutoTranscribeEnabled ?? true)
          ? MeetingStatus.processing
          : MeetingStatus.inProgress, // Ready to process
      audioFilePath: audioPath,
      recordedAt: now,
    );

    _meetings.insert(0, meeting);
    // Reset recording duration after creation to fix UI showing old time
    _recordingDuration = Duration.zero;
    await _storage.saveMeetings(_meetings);
    notifyListeners();

    // Kick off transcription if auto-transcribe is enabled
    if (_settings?.isAutoTranscribeEnabled ?? true) {
      // Add a small delay to ensure file is closed and ready
      Future.delayed(const Duration(milliseconds: 500), () {
        _transcribeAndSummarise(meeting);
      });
    }
    return meeting;
  }

  /// Creates a standalone typed note and returns its id so the editor can keep
  /// updating the same record. A note is a [Meeting] with no audio; its body is
  /// stored in [Meeting.notes]. Persists the same fire-and-forget way as the
  /// other synchronous mutators here.
  String createNote({String title = '', String body = ''}) {
    final now = DateTime.now();
    final id = now.millisecondsSinceEpoch.toString();
    final cleanTitle = title.trim().isEmpty ? 'Untitled Note' : title.trim();

    final note = Meeting(
      id: id,
      title: cleanTitle,
      team: 'Personal',
      date: _formatDate(now),
      duration: '',
      status: MeetingStatus.transcribed,
      isNote: true,
      notes: body.trim(),
      recordedAt: now,
    );

    _meetings.insert(0, note);
    _storage.saveMeetings(_meetings);
    notifyListeners();
    return id;
  }

  Future<void> _transcribeAndSummarise(Meeting meeting) async {
    _currentProcessingId = meeting.id;
    _processingState = ProcessingState.transcribing;
    notifyListeners();

    try {
      // An empty key is fine: the service routes through the server-side proxy.
      // A user-supplied key (if present) is used directly instead.
      debugPrint('Starting transcription for meeting: ${meeting.id}');
      final result = await _transcription.transcribe(
        meeting.audioFilePath!,
        language: _settings?.defaultLanguage,
        diarize: _settings?.isSpeakerIdEnabled ?? false,
        apiKey: _settings?.groqApiKey,
        useCloudMode: _settings?.isCloudMode ?? true,
      );
      debugPrint(
        'Transcription result received. Text length: ${result.fullText.length}',
      );

      // Extract unique speakers from diarized segments and seed the mapping.
      final uniqueSpeakerIds =
          result.segments
              .map((s) => s.speaker)
              .whereType<String>()
              .toSet()
              .toList()
            ..sort();
      final seedMapping = <String, String>{
        for (final id in uniqueSpeakerIds) id: id,
      };

      // Update with transcript + speaker data
      var updated = meeting.copyWith(
        transcript: result.fullText,
        segments: result.segments.isEmpty ? null : result.segments,
        status: MeetingStatus.inProgress,
        speakers: uniqueSpeakerIds.isNotEmpty
            ? uniqueSpeakerIds
            : meeting.speakers,
        speakerMapping: uniqueSpeakerIds.isNotEmpty
            ? seedMapping
            : meeting.speakerMapping,
        detectedLanguage: result.language,
      );
      _updateMeeting(updated);

      if (result.fullText.isNotEmpty) {
        _processingState = ProcessingState.summarizing;
        notifyListeners();

        final summaryResult = await _summary.generateSummary(
          result.fullText,
          style: _settings?.summaryStyleName ?? 'Bullet points',
          detectThemes: _settings?.isThemeDetectionEnabled ?? false,
          sensitivity: _settings?.actionItemSensitivity ?? 0.5,
          apiKey: _settings?.groqApiKey,
          useCloudMode: _settings?.isCloudMode ?? true,
          transcriptLanguage: result.language,
        );
        updated = updated.copyWith(
          summary: summaryResult.summary,
          actionItems: summaryResult.actionItems,
          highlights: summaryResult.highlights,
          topics: summaryResult.topics,
          sentiment: summaryResult.sentiment,
          status: MeetingStatus.transcribed,
        );
        _updateMeeting(updated);

        _notificationController.add('Meeting "${updated.title}" is ready!');
      } else {
        _updateMeeting(updated.copyWith(status: MeetingStatus.transcribed));
      }
    } catch (e) {
      debugPrint('Transcription pipeline error: $e');
      _updateMeeting(
        meeting.copyWith(
          transcript: 'Transcription failed: $e',
          status: MeetingStatus.transcribed,
        ),
      );
    } finally {
      _currentProcessingId = null;
      _processingState = ProcessingState.idle;
      notifyListeners();
    }
  }

  /// Re-runs transcription (and the summary that follows) for a recording that
  /// has audio but no usable transcript -- one interrupted by a dropped
  /// connection, a missing API key, or any earlier failure. A no-op if it has
  /// no audio file or is already being processed.
  Future<void> retryTranscription(String meetingId) async {
    final idx = _meetings.indexWhere((m) => m.id == meetingId);
    if (idx == -1) return;
    final meeting = _meetings[idx];
    if (meeting.audioFilePath == null || _currentProcessingId == meeting.id) {
      return;
    }

    final reset = meeting.copyWith(status: MeetingStatus.processing);
    _updateMeeting(reset);
    await _transcribeAndSummarise(reset);
  }

  /// Re-generate summary for a meeting that already has a transcript.
  Future<void> generateSummaryForMeeting(String id) async {
    final meeting = _meetings.firstWhere(
      (m) => m.id == id,
      orElse: () => throw Exception('Not found'),
    );
    if (meeting.transcript == null || meeting.transcript!.isEmpty) return;

    _currentProcessingId = id;
    _processingState = ProcessingState.summarizing;
    notifyListeners();

    try {
      final result = await _summary.generateSummary(
        meeting.transcript!,
        style: _settings?.summaryStyleName ?? 'Bullet points',
        detectThemes: _settings?.isThemeDetectionEnabled ?? false,
        sensitivity: _settings?.actionItemSensitivity ?? 0.5,
        apiKey: _settings?.groqApiKey,
        useCloudMode: _settings?.isCloudMode ?? true,
        transcriptLanguage: meeting.detectedLanguage,
      );
      _updateMeeting(
        meeting.copyWith(
          summary: result.summary,
          actionItems: result.actionItems,
          highlights: result.highlights,
          topics: result.topics,
          sentiment: result.sentiment,
        ),
      );
    } finally {
      _currentProcessingId = null;
      _processingState = ProcessingState.idle;
      notifyListeners();
    }
  }

  Future<Map<String, int>> getCacheSizes() async {
    return await _storage.getCacheSizes();
  }

  Future<void> clearSelective({
    bool recordings = false,
    bool metadata = false,
    bool history = false,
  }) async {
    await _storage.clearSelective(
      recordings: recordings,
      metadata: metadata,
      history: history,
    );

    if (metadata) {
      _meetings = [];
      _folders = [];
    }
    if (history) {
      _recentSearches = [];
    }
    notifyListeners();
    _notificationController.add('Selected cache items cleared.');
  }

  void deleteMeeting(String id) {
    _meetings.removeWhere((m) => m.id == id);
    _storage.saveMeetings(_meetings);
    notifyListeners();
  }

  void renameMeeting(String id, String newTitle) {
    if (newTitle.trim().isEmpty) return;
    final idx = _meetings.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    _meetings[idx] = _meetings[idx].copyWith(title: newTitle);
    _storage.saveMeetings(_meetings);
    notifyListeners();
  }

  /// Saves the user's free-text note for [id]. An emptied note is stored as an
  /// empty string rather than removed, which is enough for the UI to treat it as
  /// absent; [copyWith] can't set the field back to null.
  Future<void> updateNotes(String id, String notes) async {
    final idx = _meetings.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    final trimmed = notes.trim();
    if ((_meetings[idx].notes ?? '') == trimmed) return;
    _meetings[idx] = _meetings[idx].copyWith(notes: trimmed);
    notifyListeners();
    await _storage.saveMeetings(_meetings);
  }

  /// Replaces the AI summary with the user's edited text. Empties are ignored;
  /// an edit also drops cached translations, whose own summaries would otherwise
  /// disagree with the one now on screen (see the drop-on-edit rule that
  /// [editTranscriptSegment] follows).
  Future<void> updateSummary(String meetingId, String summary) async {
    final idx = _meetings.indexWhere((m) => m.id == meetingId);
    if (idx == -1) return;
    final trimmed = summary.trim();
    if ((_meetings[idx].summary ?? '').trim() == trimmed) return;
    _meetings[idx] = _meetings[idx].copyWith(
      summary: trimmed,
      translations: {},
    );
    notifyListeners();
    await _storage.saveMeetings(_meetings);
  }

  /// Replaces the text of transcript segment [index], keeping its timing and
  /// speaker so playback sync is untouched. Rebuilds the flat [transcript] the
  /// summary and search read from, and drops every cached translation: an edited
  /// source line makes its positionally-aligned translation wrong.
  Future<void> editTranscriptSegment(
    String meetingId,
    int index,
    String newText,
  ) async {
    final idx = _meetings.indexWhere((m) => m.id == meetingId);
    if (idx == -1) return;
    final meeting = _meetings[idx];
    if (index < 0 || index >= meeting.segments.length) return;
    final trimmed = newText.trim();
    if (trimmed.isEmpty || meeting.segments[index].text.trim() == trimmed) {
      return;
    }

    final segments = List<MeetingSegment>.from(meeting.segments);
    final old = segments[index];
    segments[index] = MeetingSegment(
      start: old.start,
      end: old.end,
      text: trimmed,
      speaker: old.speaker,
    );

    _meetings[idx] = meeting.copyWith(
      segments: segments,
      transcript: segments.map((s) => s.text.trim()).join(' '),
      translations: {},
    );
    notifyListeners();
    await _storage.saveMeetings(_meetings);
  }

  /// Replaces the flat transcript text for a meeting that has no per-segment
  /// breakdown. Drops cached translations for the same reason as
  /// [editTranscriptSegment].
  Future<void> editTranscriptText(String meetingId, String newText) async {
    final idx = _meetings.indexWhere((m) => m.id == meetingId);
    if (idx == -1) return;
    final trimmed = newText.trim();
    if (trimmed.isEmpty ||
        (_meetings[idx].transcript ?? '').trim() == trimmed) {
      return;
    }
    _meetings[idx] = _meetings[idx].copyWith(
      transcript: trimmed,
      translations: {},
    );
    notifyListeners();
    await _storage.saveMeetings(_meetings);
  }

  void renameSpeaker(String meetingId, String speakerId, String newName) {
    final idx = _meetings.indexWhere((m) => m.id == meetingId);
    if (idx == -1) return;
    final meeting = _meetings[idx];
    final newMapping = Map<String, String>.from(meeting.speakerMapping);
    newMapping[speakerId] = newName;
    _meetings[idx] = meeting.copyWith(speakerMapping: newMapping);
    _storage.saveMeetings(_meetings);
    notifyListeners();
  }

  void toggleFavorite(String id) {
    final idx = _meetings.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    _meetings[idx] = _meetings[idx].copyWith(
      isFavorite: !_meetings[idx].isFavorite,
    );
    _storage.saveMeetings(_meetings);
    notifyListeners();
  }

  // ── Helpers ──────────────────────────────────────────────
  void _updateMeeting(Meeting updated) {
    final idx = _meetings.indexWhere((m) => m.id == updated.id);
    if (idx != -1) {
      _meetings[idx] = updated;
      _storage.saveMeetings(_meetings);
      notifyListeners();
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatDateTitle(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> seek(Duration to) async {
    final clamped = to < Duration.zero
        ? Duration.zero
        : (_totalDuration > Duration.zero && to > _totalDuration
              ? _totalDuration
              : to);
    // Move the playhead now rather than waiting for the player's next tick, so
    // tapping a transcript line highlights it immediately -- and so seeking
    // while paused still moves the highlight.
    position.value = clamped;
    await _audioPlayer.seek(clamped);
  }

  @override
  void dispose() {
    _stopTimer();
    _recorder.dispose();
    _audioPlayer.dispose();
    _transcription.stopServer();
    _notificationController.close();
    position.dispose();
    super.dispose();
  }
}
