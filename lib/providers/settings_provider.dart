import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum ModelQuality { standard, premium }
enum SummaryStyle { bulletPoints, executiveSummary, detailedNarrative }
enum ThemeModeOption { light, dark, system }

class SettingsProvider with ChangeNotifier {
  static const String _keyGroqApiKey = 'groq_api_key';
  static const String _keyIsCloudMode = 'is_cloud_mode';

  final SharedPreferences _prefs;
  List<InputDevice> _availableDevices = [];
  final _recorder = AudioRecorder();

  bool _isCloudMode = true;

  SettingsProvider(this._prefs) {
    _isCloudMode = _prefs.getBool(_keyIsCloudMode) ?? true;
    _initDevices();
  }

  Future<void> _initDevices() async {
    try {
      _availableDevices = await _recorder.listInputDevices();
      notifyListeners();
    } catch (_) {}
  }

  List<InputDevice> get availableDevices => _availableDevices;

  String get audioSourceId => _prefs.getString('audioSourceId') ?? '';
  set audioSourceId(String value) {
    _prefs.setString('audioSourceId', value);
    notifyListeners();
  }

  // --- Profile ---
  String get userName => _prefs.getString('userName') ?? 'John Doe';
  set userName(String value) {
    _prefs.setString('userName', value);
    notifyListeners();
  }

  String get userEmail => _prefs.getString('userEmail') ?? 'john@acmecorp.com';
  set userEmail(String value) {
    _prefs.setString('userEmail', value);
    notifyListeners();
  }

  int get userColorValue => _prefs.getInt('userColorValue') ?? 0xFF4A9FD9;
  set userColorValue(int value) {
    _prefs.setInt('userColorValue', value);
    notifyListeners();
  }

  // --- Subscription ---
  bool get isPro => _prefs.getBool('isPro') ?? false;
  set isPro(bool value) {
    _prefs.setBool('isPro', value);
    notifyListeners();
  }

  // --- Transcription ---
  ModelQuality get modelQuality => ModelQuality.values[_prefs.getInt('modelQuality') ?? 0];
  set modelQuality(ModelQuality value) {
    _prefs.setInt('modelQuality', value.index);
    notifyListeners();
  }

  String get defaultLanguage => _prefs.getString('defaultLanguage') ?? 'Auto-detect';
  set defaultLanguage(String value) {
    _prefs.setString('defaultLanguage', value);
    notifyListeners();
  }

  bool get isSpeakerIdEnabled => _prefs.getBool('isSpeakerIdEnabled') ?? true;
  set isSpeakerIdEnabled(bool value) {
    _prefs.setBool('isSpeakerIdEnabled', value);
    notifyListeners();
  }

  bool get isAutoTranscribeEnabled => _prefs.getBool('isAutoTranscribeEnabled') ?? true;
  set isAutoTranscribeEnabled(bool value) {
    _prefs.setBool('isAutoTranscribeEnabled', value);
    notifyListeners();
  }

  // --- AI Intelligence ---
  SummaryStyle get summaryStyle => SummaryStyle.values[_prefs.getInt('summaryStyle') ?? 0];
  set summaryStyle(SummaryStyle value) {
    _prefs.setInt('summaryStyle', value.index);
    notifyListeners();
  }

  double get actionItemSensitivity => _prefs.getDouble('actionItemSensitivity') ?? 0.5;
  set actionItemSensitivity(double value) {
    _prefs.setDouble('actionItemSensitivity', value);
    notifyListeners();
  }

  bool get isThemeDetectionEnabled => _prefs.getBool('isThemeDetectionEnabled') ?? true;
  set isThemeDetectionEnabled(bool value) {
    _prefs.setBool('isThemeDetectionEnabled', value);
    notifyListeners();
  }

  // --- Appearance ---
  ThemeModeOption get themeMode => ThemeModeOption.values[_prefs.getInt('themeMode') ?? 2]; // Default to System
  set themeMode(ThemeModeOption value) {
    _prefs.setInt('themeMode', value.index);
    notifyListeners();
  }

  // --- Experience & Audio ---
  String get audioSource => _prefs.getString('audioSource') ?? 'Default Microphone';
  set audioSource(String value) {
    _prefs.setString('audioSource', value);
    notifyListeners();
  }

  bool get isProcessingCompleteNotifyEnabled => _prefs.getBool('isProcessingCompleteNotifyEnabled') ?? true;
  set isProcessingCompleteNotifyEnabled(bool value) {
    _prefs.setBool('isProcessingCompleteNotifyEnabled', value);
    notifyListeners();
  }

  bool get isUpcomingMeetingNotifyEnabled => _prefs.getBool('isUpcomingMeetingNotifyEnabled') ?? true;
  set isUpcomingMeetingNotifyEnabled(bool value) {
    _prefs.setBool('isUpcomingMeetingNotifyEnabled', value);
    notifyListeners();
  }

  // --- Privacy ---
  String get groqApiKey {
    final storedKey = _prefs.getString(_keyGroqApiKey);
    if (storedKey != null && storedKey.isNotEmpty) {
      return storedKey;
    }
    return dotenv.env['GROQ_API_KEY'] ?? '';
  }

  bool get isUsingDefaultKey {
    final storedKey = _prefs.getString(_keyGroqApiKey);
    return (storedKey == null || storedKey.isEmpty) && 
           (dotenv.env['GROQ_API_KEY'] != null && dotenv.env['GROQ_API_KEY']!.isNotEmpty);
  }

  set groqApiKey(String value) {
    _prefs.setString(_keyGroqApiKey, value);
    notifyListeners();
  }

  bool get isCloudMode => _isCloudMode;
  set isCloudMode(bool value) {
    _isCloudMode = value;
    _prefs.setBool(_keyIsCloudMode, value); // Removed '?' as _prefs is non-nullable
    notifyListeners();
  }

  bool get isLocalOnlyMode => _prefs.getBool('isLocalOnlyMode') ?? false;
  set isLocalOnlyMode(bool value) {
    _prefs.setBool('isLocalOnlyMode', value);
    notifyListeners();
  }

  // --- Helpers ---
  /// Returns the faster-whisper model name for the selected quality.
  /// - standard → 'small'  (~465 MB, fast on CPU, good accuracy)
  /// - premium  → 'medium' (~1.5 GB, slower but noticeably better accuracy)
  /// large-v3 is intentionally excluded — it needs a GPU and ~8 GB RAM.
  String get modelSize => modelQuality == ModelQuality.standard ? 'small' : 'medium';

  String get summaryStyleName {
    switch (summaryStyle) {
      case SummaryStyle.bulletPoints:
        return 'Bullet points';
      case SummaryStyle.executiveSummary:
        return 'Concise summary';
      case SummaryStyle.detailedNarrative:
        return 'Detailed narrative';
    }
  }

  Future<void> clearCache() async {
    // Logic to clear cached data would go here
    notifyListeners();
  }
}
