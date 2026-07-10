import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Light Mode Granola Palette
  static const background = Color(0xFFF8F7F4);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF2F1EE); // Using as searchBg
  static const primary = Color(0xFF1A8C7E); // Scribe Teal
  static const primaryLight = Color(0xFFE8F9F7);
  static const accent = Color(0xFF4A6CF7);
  static const recordRed = Color(0xFFE85D4A);
  static const separator = Color(0xFFE0E0E0);
  static const gray = Color(0xFF9E9E9E);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B6B6B);
  static const textTertiary = Color(0xFFBDBDBD);
  static const green = Color(0xFF34C759);

  // Dark Mode Granola Palette
  static const darkBackground = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);
  static const darkSurfaceVariant = Color(0xFF2C2C2C); // Using as searchBg
  static const darkSeparator = Color(0xFF2C2C2C);
  static const darkTextPrimary = Color(0xFFE1E1E1);
  static const darkTextSecondary = Color(0xFFAAAAAA);
  static const darkTextTertiary = Color(0xFF666666);

  /// The colors a user can pick for their profile avatar. The first entry is
  /// the default for accounts that have never chosen one.
  static const profileSwatches = <Color>[
    Color(0xFF1A8C7E), // Teal (Brand)
    Color(0xFF4A5568), // Slate
    Color(0xFF008953), // Moss
    Color(0xFFC04000), // Terracotta
    Color(0xFFD97706), // Ochre
  ];
}

/// The app's heading scale.
///
/// Every heading in Scribe comes from one of these roles. Build each style with
/// `GoogleFonts.manrope(fontWeight: ...)` rather than `copyWith(fontWeight:)` on
/// a resolved style: google_fonts bakes the weight into the font family name
/// (`Manrope_regular`, `Manrope_bold`, ...), so overriding the weight afterwards
/// keeps the regular font file and renders a faux bold.
class AppText {
  AppText._();

  /// Hero heading at the top of a screen body ("Good morning", "Search").
  static final pageTitle = GoogleFonts.manrope(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    height: 1.15,
  );

  /// App bar title on a root tab (Library, Schedule).
  static final appBarTitleLarge = GoogleFonts.manrope(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  /// App bar title on a pushed screen (Settings, Edit Profile, New Note).
  static final appBarTitle = GoogleFonts.manrope(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  /// Title of a full-height bottom sheet or modal.
  static final sheetTitle = GoogleFonts.manrope(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  /// Title of a dialog or a compact bottom sheet.
  static final dialogTitle = GoogleFonts.manrope(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  /// Heading that introduces a section within a screen body.
  static final sectionTitle = GoogleFonts.manrope(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  /// Small uppercase eyebrow above a group of settings or list items.
  static final sectionLabel = GoogleFonts.manrope(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  /// Title of a card or list row.
  static final cardTitle = GoogleFonts.manrope(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  /// Label inside a filled call-to-action button.
  static final buttonLabel = GoogleFonts.manrope(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );
}

class AppTheme {
  static TextTheme _buildTextTheme(
    Color primary,
    Color secondary,
    Color tertiary,
  ) {
    return GoogleFonts.manropeTextTheme().copyWith(
      headlineLarge: GoogleFonts.manrope(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: primary,
        letterSpacing: -1.0,
        height: 1.1,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: primary,
        letterSpacing: -0.8,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.5,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.3,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: primary,
        letterSpacing: -0.2,
        height: 1.6,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: secondary,
        letterSpacing: -0.1,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: tertiary,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: tertiary,
        letterSpacing: 0.8,
      ),
    );
  }

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: AppText.appBarTitle.copyWith(
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconDataTheme(color: AppColors.textPrimary),
      ),
      dividerColor: AppColors.separator,
      textTheme: _buildTextTheme(
        AppColors.textPrimary,
        AppColors.textSecondary,
        AppColors.textTertiary,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      listTileTheme: const ListTileThemeData(
        selectedTileColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.separator,
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      splashFactory: NoSplash.splashFactory,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.darkSurface,
        onPrimary: Colors.white,
        onSurface: AppColors.darkTextPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: AppText.appBarTitle.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        iconTheme: const IconDataTheme(color: AppColors.darkTextPrimary),
      ),
      dividerColor: AppColors.darkSeparator,
      textTheme: _buildTextTheme(
        AppColors.darkTextPrimary,
        AppColors.darkTextSecondary,
        AppColors.darkTextTertiary,
      ),
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      listTileTheme: const ListTileThemeData(
        selectedTileColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.darkSurfaceVariant,
        ),
      ),
    );
  }
}

extension ThemeColors on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;
  Color get appBackground =>
      _isDark ? AppColors.darkBackground : AppColors.background;
  Color get appSurface => _isDark ? AppColors.darkSurface : AppColors.surface;
  Color get appSurfaceVariant =>
      _isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant;
  Color get appSeparator =>
      _isDark ? AppColors.darkSeparator : AppColors.separator;
  Color get appTextPrimary =>
      _isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color get appTextSecondary =>
      _isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
  Color get appTextTertiary =>
      _isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;
  // Primary is always Teal in Granola
  Color get appPrimary => AppColors.primary;
  Color get appPrimaryLight => _isDark
      ? AppColors.primary.withValues(alpha: 0.15)
      : AppColors.primaryLight;
  Color get appAccent => AppColors.accent;
  Color get appRecordRed => AppColors.recordRed;
  Color get appGray => AppColors.gray;
  Color get appGreen => AppColors.green;

  // Premium Shadow Token (Granola)
  List<BoxShadow> get appShadowSubtle => [
    BoxShadow(
      color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  List<BoxShadow> get appShadowMedium => [
    BoxShadow(
      color: Colors.black.withValues(alpha: _isDark ? 0.4 : 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Heading roles from [AppText], pre-colored for the active brightness.
extension AppTextTheme on BuildContext {
  TextStyle get pageTitle => AppText.pageTitle.copyWith(color: appTextPrimary);
  TextStyle get appBarTitleLarge =>
      AppText.appBarTitleLarge.copyWith(color: appTextPrimary);
  TextStyle get appBarTitle =>
      AppText.appBarTitle.copyWith(color: appTextPrimary);
  TextStyle get sheetTitle =>
      AppText.sheetTitle.copyWith(color: appTextPrimary);
  TextStyle get dialogTitle =>
      AppText.dialogTitle.copyWith(color: appTextPrimary);
  TextStyle get sectionTitle =>
      AppText.sectionTitle.copyWith(color: appTextPrimary);
  TextStyle get sectionLabel =>
      AppText.sectionLabel.copyWith(color: appTextSecondary);
  TextStyle get cardTitle => AppText.cardTitle.copyWith(color: appTextPrimary);
  TextStyle get buttonLabel => AppText.buttonLabel;
}

class IconDataTheme extends IconThemeData {
  const IconDataTheme({required Color color}) : super(color: color);
}
