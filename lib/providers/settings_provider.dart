import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

enum SummaryStyle { bulletPoints, executiveSummary, detailedNarrative }

enum ThemeModeOption { light, dark, system }

class SettingsProvider with ChangeNotifier {
  static const String _keyGroqApiKey = 'groq_api_key';
  static const String _keyIsCloudMode = 'is_cloud_mode';

  final SharedPreferences _prefs;
  List<InputDevice> _availableDevices = [];
  final _recorder = AudioRecorder();

  bool _isCloudMode = true;
  String? _userId;
  String? _authFullName;
  String? _authEmail;

  SettingsProvider(this._prefs) {
    _isCloudMode = _prefs.getBool(_keyIsCloudMode) ?? true;
    _initDevices();
  }

  /// Namespaces a preference key to the signed-in user, so two accounts on
  /// the same device never read each other's settings. [_keyGroqApiKey] and
  /// [_keyIsCloudMode] deliberately bypass this: they configure the device's
  /// transcription backend, not the person using it.
  String _k(String key) => _userId == null ? key : 'u:$_userId:$key';

  /// Repoints every namespaced preference at [userId]. Idempotent, and cheap
  /// because the keys themselves carry the scope -- nothing is copied.
  ///
  /// [fullName] and [email] come from the account itself and act as defaults
  /// for [userName]/[userEmail], so a freshly signed-up user sees the details
  /// they already typed rather than an empty form. They are not written to
  /// prefs: an explicit edit is what persists, and until then the account
  /// stays the source of truth.
  void setUser(String? userId, {String? fullName, String? email}) {
    final unchanged =
        _userId == userId && _authFullName == fullName && _authEmail == email;
    if (unchanged) return;

    _userId = userId;
    _authFullName = fullName;
    _authEmail = email;
    // Called from ChangeNotifierProxyProvider.update during build; notifying
    // synchronously there would throw.
    scheduleMicrotask(notifyListeners);
  }

  Future<void> _initDevices() async {
    try {
      _availableDevices = await _recorder.listInputDevices();
      notifyListeners();
    } catch (_) {}
  }

  List<InputDevice> get availableDevices => _availableDevices;

  String get audioSourceId => _prefs.getString(_k('audioSourceId')) ?? '';
  set audioSourceId(String value) {
    _prefs.setString(_k('audioSourceId'), value);
    notifyListeners();
  }

  // --- Profile ---
  // Falls back to the signed-in account before any placeholder, so the profile
  // form is pre-filled with what the user entered at sign-up.
  String get userName =>
      _prefs.getString(_k('userName')) ?? _authFullName ?? '';
  set userName(String value) {
    _prefs.setString(_k('userName'), value);
    notifyListeners();
  }

  String get userEmail => _prefs.getString(_k('userEmail')) ?? _authEmail ?? '';
  set userEmail(String value) {
    _prefs.setString(_k('userEmail'), value);
    notifyListeners();
  }

  // Defaults to the first swatch so an untouched profile still renders a color
  // the picker can highlight as selected.
  int get userColorValue =>
      _prefs.getInt(_k('userColorValue')) ??
      AppColors.profileSwatches.first.toARGB32();
  set userColorValue(int value) {
    _prefs.setInt(_k('userColorValue'), value);
    notifyListeners();
  }

  /// The avatar color chosen in Edit Profile, for every surface that shows the
  /// user. Values outside [AppColors.profileSwatches] fall back to the default.
  Color get userColor {
    final stored = userColorValue;
    return AppColors.profileSwatches.firstWhere(
      (c) => c.toARGB32() == stored,
      orElse: () => AppColors.profileSwatches.first,
    );
  }

  /// Single uppercase letter for the avatar, or `S` before a name is set.
  String get userInitial =>
      userName.trim().isNotEmpty ? userName.trim()[0].toUpperCase() : 'S';

  /// Absolute path to the user's chosen profile photo, or null to fall back to
  /// the coloured initial. Returns null if the stored file has since been
  /// removed (e.g. a cache clear), so callers never point [FileImage] at a
  /// missing file. The existsSync check is cheap enough for build-time use.
  String? get userAvatarPath {
    final path = _prefs.getString(_k('userAvatarPath'));
    if (path == null) return null;
    return File(path).existsSync() ? path : null;
  }

  /// Copies [sourcePath] (a freshly picked image) into app storage and points
  /// the profile at it. Each save uses a new filename so [FileImage]'s
  /// path-keyed cache can't show the previous photo, and the old file is
  /// deleted so photos don't accumulate.
  Future<void> setUserAvatar(String sourcePath) async {
    final docs = await getApplicationDocumentsDirectory();
    final userTag = _userId ?? 'local';
    final ext = p.extension(sourcePath);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final dest = File(p.join(docs.path, 'avatar_${userTag}_$stamp$ext'));
    await File(sourcePath).copy(dest.path);

    final previous = _prefs.getString(_k('userAvatarPath'));
    await _prefs.setString(_k('userAvatarPath'), dest.path);
    if (previous != null && previous != dest.path) {
      try {
        await File(previous).delete();
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Clears the profile photo, reverting to the coloured initial.
  Future<void> removeUserAvatar() async {
    final previous = _prefs.getString(_k('userAvatarPath'));
    await _prefs.remove(_k('userAvatarPath'));
    if (previous != null) {
      try {
        await File(previous).delete();
      } catch (_) {}
    }
    notifyListeners();
  }

  // --- Transcription ---
  String get defaultLanguage =>
      _prefs.getString(_k('defaultLanguage')) ?? 'Auto-detect';
  set defaultLanguage(String value) {
    _prefs.setString(_k('defaultLanguage'), value);
    notifyListeners();
  }

  bool get isSpeakerIdEnabled =>
      _prefs.getBool(_k('isSpeakerIdEnabled')) ?? true;
  set isSpeakerIdEnabled(bool value) {
    _prefs.setBool(_k('isSpeakerIdEnabled'), value);
    notifyListeners();
  }

  bool get isAutoTranscribeEnabled =>
      _prefs.getBool(_k('isAutoTranscribeEnabled')) ?? true;
  set isAutoTranscribeEnabled(bool value) {
    _prefs.setBool(_k('isAutoTranscribeEnabled'), value);
    notifyListeners();
  }

  // --- AI Intelligence ---
  SummaryStyle get summaryStyle =>
      SummaryStyle.values[_prefs.getInt(_k('summaryStyle')) ?? 0];
  set summaryStyle(SummaryStyle value) {
    _prefs.setInt(_k('summaryStyle'), value.index);
    notifyListeners();
  }

  double get actionItemSensitivity =>
      _prefs.getDouble(_k('actionItemSensitivity')) ?? 0.5;
  set actionItemSensitivity(double value) {
    _prefs.setDouble(_k('actionItemSensitivity'), value);
    notifyListeners();
  }

  bool get isThemeDetectionEnabled =>
      _prefs.getBool(_k('isThemeDetectionEnabled')) ?? true;
  set isThemeDetectionEnabled(bool value) {
    _prefs.setBool(_k('isThemeDetectionEnabled'), value);
    notifyListeners();
  }

  // --- Appearance ---
  ThemeModeOption get themeMode =>
      ThemeModeOption.values[_prefs.getInt(_k('themeMode')) ??
          2]; // Default to System
  set themeMode(ThemeModeOption value) {
    _prefs.setInt(_k('themeMode'), value.index);
    notifyListeners();
  }

  // --- Experience & Audio ---
  String get audioSource =>
      _prefs.getString(_k('audioSource')) ?? 'Default Microphone';
  set audioSource(String value) {
    _prefs.setString(_k('audioSource'), value);
    notifyListeners();
  }

  // --- Groq access ---
  // No Groq key ships in the app. Users on the default experience route through
  // the Supabase Edge Function proxy (the key lives there as a secret). A user
  // who pastes their own key here is billed directly against it instead. An
  // empty string therefore means "use the proxy", never "no access".
  String get groqApiKey => _prefs.getString(_keyGroqApiKey) ?? '';

  /// True when the user brought their own key; false means calls go through the
  /// server-side proxy.
  bool get hasUserApiKey => groqApiKey.isNotEmpty;

  set groqApiKey(String value) {
    _prefs.setString(_keyGroqApiKey, value.trim());
    notifyListeners();
  }

  bool get isCloudMode => _isCloudMode;
  set isCloudMode(bool value) {
    _isCloudMode = value;
    _prefs.setBool(
      _keyIsCloudMode,
      value,
    ); // Removed '?' as _prefs is non-nullable
    notifyListeners();
  }

  // --- Helpers ---
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
