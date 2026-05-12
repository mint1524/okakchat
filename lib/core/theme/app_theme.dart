import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// OKAK Chat — High-tech minimalist design system.
///
/// Dark-first. Electric blue (#3B82F6) on deep navy-black (#060B17).
/// Cold palette throughout. Glassmorphism on key surfaces.
class AppTheme {
  AppTheme._();

  // ── Brand palette ────────────────────────────────────────────────────────
  /// Deep navy-black — main background
  static const bg        = Color(0xFF060B17);
  /// Slightly lighter surface
  static const surface0  = Color(0xFF0C1220);
  static const surface1  = Color(0xFF111B2E);
  static const surface2  = Color(0xFF172035);
  static const surface3  = Color(0xFF1E2A42);

  /// Electric blue
  static const blue500   = Color(0xFF3B82F6);
  static const blue400   = Color(0xFF60A5FA);
  static const blue300   = Color(0xFF93C5FD);
  static const blue700   = Color(0xFF1D4ED8);
  static const blue900   = Color(0xFF1E3A5F);

  /// Sky accent
  static const sky400    = Color(0xFF38BDF8);

  /// Text
  static const textHigh  = Color(0xFFE2E8F0);  // slate-200
  static const textMid   = Color(0xFF94A3B8);   // slate-400
  static const textLow   = Color(0xFF475569);   // slate-600

  /// Glass border tint
  static const glassBorder = Color(0x1A3B82F6); // blue, 10% opacity
  static const glassOverlay = Color(0x0D3B82F6); // blue, 5% opacity

  // ── Color scheme ─────────────────────────────────────────────────────────
  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: blue500,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: blue900,
    onPrimaryContainer: blue300,
    secondary: sky400,
    onSecondary: Color(0xFF082F49),
    secondaryContainer: Color(0xFF0C2540),
    onSecondaryContainer: Color(0xFFBAE6FD),
    tertiary: Color(0xFF818CF8),   // indigo-400
    onTertiary: Color(0xFF1E1B4B),
    tertiaryContainer: Color(0xFF1E2040),
    onTertiaryContainer: Color(0xFFC7D2FE),
    error: Color(0xFFF87171),
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF5C1A1A),
    onErrorContainer: Color(0xFFFCA5A5),
    surface: bg,
    onSurface: textHigh,
    surfaceContainerLowest: Color(0xFF030609),
    surfaceContainerLow: surface0,
    surfaceContainer: surface1,
    surfaceContainerHigh: surface2,
    surfaceContainerHighest: surface3,
    outline: Color(0xFF2D3A52),
    outlineVariant: Color(0xFF1A2436),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: textHigh,
    onInverseSurface: bg,
    inversePrimary: blue700,
  );

  // ── Light scheme — keeps blue accent, warm-neutral surfaces ─────────────
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: blue500,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDBEAFE),
    onPrimaryContainer: Color(0xFF1E3A5F),
    secondary: Color(0xFF0284C7),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE0F2FE),
    onSecondaryContainer: Color(0xFF0C4A6E),
    tertiary: Color(0xFF6366F1),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE0E7FF),
    onTertiaryContainer: Color(0xFF1E1B4B),
    error: Color(0xFFDC2626),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF991B1B),
    surface: Color(0xFFF8FAFF),
    onSurface: Color(0xFF0F172A),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF1F5FF),
    surfaceContainer: Color(0xFFE8EEFF),
    surfaceContainerHigh: Color(0xFFDBE4FF),
    surfaceContainerHighest: Color(0xFFCDD9FF),
    outline: Color(0xFF94A3B8),
    outlineVariant: Color(0xFFCBD5E1),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF0F172A),
    onInverseSurface: Color(0xFFF8FAFF),
    inversePrimary: blue400,
  );

  // ── Typography — DM Sans ─────────────────────────────────────────────────
  static TextTheme _buildTextTheme(TextTheme base) =>
      GoogleFonts.dmSansTextTheme(base).copyWith(
        displayLarge:  GoogleFonts.dmSans(fontSize: 57, fontWeight: FontWeight.w300, letterSpacing: -0.5),
        displayMedium: GoogleFonts.dmSans(fontSize: 45, fontWeight: FontWeight.w300, letterSpacing: -0.25),
        displaySmall:  GoogleFonts.dmSans(fontSize: 36, fontWeight: FontWeight.w300),
        headlineLarge: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: -0.5),
        headlineMedium:GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        headlineSmall: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        titleLarge:    GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w600),
        titleMedium:   GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.1),
        titleSmall:    GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500),
        bodyLarge:     GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium:    GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w400),
        bodySmall:     GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w400),
        labelLarge:    GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
        labelMedium:   GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.4),
        labelSmall:    GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      );

  // ── Component overrides ──────────────────────────────────────────────────
  static InputDecorationTheme _inputTheme(ColorScheme cs) =>
      InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.error),
        ),
        labelStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
        prefixIconColor: cs.onSurface.withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  static CardThemeData _cardTheme(ColorScheme cs) => CardThemeData(
        elevation: 0,
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      );

  static FilledButtonThemeData _filledButtonTheme(ColorScheme cs) =>
      FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
          backgroundColor: cs.primary,
          foregroundColor: Colors.white,
        ),
      );

  static AppBarTheme _appBarTheme(ColorScheme cs) => AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        titleTextStyle: GoogleFonts.dmSans(
            fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface),
      );

  // ── Public builders ──────────────────────────────────────────────────────
  static ThemeData dark() {
    const cs = _darkScheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: _buildTextTheme(ThemeData.dark().textTheme),
      inputDecorationTheme: _inputTheme(cs),
      cardTheme: _cardTheme(cs),
      filledButtonTheme: _filledButtonTheme(cs),
      appBarTheme: _appBarTheme(cs),
      scaffoldBackgroundColor: cs.surface,
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1A2436),
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData light() {
    const cs = _lightScheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: _buildTextTheme(ThemeData.light().textTheme),
      inputDecorationTheme: _inputTheme(cs),
      cardTheme: _cardTheme(cs),
      filledButtonTheme: _filledButtonTheme(cs),
      appBarTheme: _appBarTheme(cs),
      scaffoldBackgroundColor: cs.surface,
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
