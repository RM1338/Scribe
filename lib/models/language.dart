/// The languages Scribe offers for transcription and translation.
///
/// Whisper claims ~99 languages, but word-error rates in its long tail are bad
/// enough that offering them makes the app look broken. This is the subset that
/// transcribes reliably, ordered roughly by number of speakers.
///
/// [code] is the ISO-639-1 code Whisper's `language` parameter expects, and the
/// same code Groq returns in `verbose_json`'s `language` field.
class AppLanguage {
  final String name;
  final String code;

  /// Rendered in the language picker next to [name].
  final String nativeName;

  const AppLanguage(this.name, this.code, this.nativeName);

  /// The "let Whisper decide" option. Never sent to the API -- callers omit the
  /// `language` field entirely instead. See [codeFor].
  static const String autoDetect = 'Auto-detect';

  static const List<AppLanguage> all = [
    AppLanguage('English', 'en', 'English'),
    AppLanguage('Hindi', 'hi', 'हिन्दी'),
    AppLanguage('Spanish', 'es', 'Español'),
    AppLanguage('Arabic', 'ar', 'العربية'),
    AppLanguage('French', 'fr', 'Français'),
    AppLanguage('Bengali', 'bn', 'বাংলা'),
    AppLanguage('Portuguese', 'pt', 'Português'),
    AppLanguage('Russian', 'ru', 'Русский'),
    AppLanguage('Urdu', 'ur', 'اردو'),
    AppLanguage('Indonesian', 'id', 'Bahasa Indonesia'),
    AppLanguage('German', 'de', 'Deutsch'),
    AppLanguage('Japanese', 'ja', '日本語'),
    AppLanguage('Chinese', 'zh', '中文'),
    AppLanguage('Marathi', 'mr', 'मराठी'),
    AppLanguage('Telugu', 'te', 'తెలుగు'),
    AppLanguage('Turkish', 'tr', 'Türkçe'),
    AppLanguage('Tamil', 'ta', 'தமிழ்'),
    AppLanguage('Vietnamese', 'vi', 'Tiếng Việt'),
    AppLanguage('Korean', 'ko', '한국어'),
    AppLanguage('Italian', 'it', 'Italiano'),
    AppLanguage('Thai', 'th', 'ไทย'),
    AppLanguage('Gujarati', 'gu', 'ગુજરાતી'),
    AppLanguage('Polish', 'pl', 'Polski'),
    AppLanguage('Ukrainian', 'uk', 'Українська'),
    AppLanguage('Malayalam', 'ml', 'മലയാളം'),
    AppLanguage('Kannada', 'kn', 'ಕನ್ನಡ'),
    AppLanguage('Dutch', 'nl', 'Nederlands'),
  ];

  /// Display names for a picker, with [autoDetect] first.
  static List<String> get pickerOptions => [
    autoDetect,
    ...all.map((l) => l.name),
  ];

  /// The ISO code to send to Whisper, or null to let it auto-detect.
  ///
  /// Returns null -- not 'en' -- for [autoDetect] and for anything unrecognised.
  /// A stale or misspelled preference must degrade to detection, never to
  /// silently transcribing the audio as English.
  static String? codeFor(String? displayName) {
    if (displayName == null || displayName == autoDetect) return null;
    for (final language in all) {
      if (language.name == displayName) return language.code;
    }
    return null;
  }

  /// Inverse of [codeFor], for showing what Whisper detected. Falls back to the
  /// raw code so an unmapped language still renders as something.
  static String nameForCode(String code) {
    final normalized = code.toLowerCase().trim();
    for (final language in all) {
      if (language.code == normalized) return language.name;
    }
    return code;
  }

  static AppLanguage? byCode(String code) {
    final normalized = code.toLowerCase().trim();
    for (final language in all) {
      if (language.code == normalized) return language;
    }
    return null;
  }

  /// Case-insensitive match on either name, for the picker's search box.
  static List<AppLanguage> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (l) =>
              l.name.toLowerCase().contains(q) ||
              l.nativeName.toLowerCase().contains(q),
        )
        .toList();
  }
}
