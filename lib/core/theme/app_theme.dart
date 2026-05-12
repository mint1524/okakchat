import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// OKAK Chat design system.
///
/// Accent: warm orange (#EA580C light / #FB923C dark) — distinctive in the
/// AI-chat space where everyone else is green, blue, or purple.
/// Surfaces: warm Stone palette (off-white/charcoal), never pure white/black.
/// Type: DM Sans — geometric, readable, slightly warmer than Inter.
class AppTheme {
  AppTheme._();

  // ── Brand palette ────────────────────────────────────────────────────────
  static const _orange600 = Color(0xFFEA580C);
  static const _orange400 = Color(0xFFFB923C);
  static const _orange100 = Color(0xFFFFEDD5);
  static const _orange950 = Color(0xFF431407);

  // Stone (warm neutral — not cold grey)
  static const _stone50  = Color(0xFFFAFAF9);
  static const _stone100 = Color(0xFFF5F5F4);
  static const _stone200 = Color(0xFFE7E5E4);
  static const _stone300 = Color(0xFFD6D3D1);
  static const _stone400 = Color(0xFFA8A29E);
  static const _stone500 = Color(0xFF78716C);
  static const _stone700 = Color(0xFF44403C);
  static const _stone800 = Color(0xFF292524);
  static const _stone900 = Color(0xFF1C1917);
  static const _stone950 = Color(0xFF0C0A09);

  // ── Light color scheme ───────────────────────────────────────────────────
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _orange600,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: _orange100,
    onPrimaryContainer: _orange950,
    secondary: Color(0xFF64748B),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFF1F5F9),
    onSecondaryContainer: Color(0xFF1E293B),
    tertiary: Color(0xFF0EA5E9),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE0F2FE),
    onTertiaryContainer: Color(0xFF0C4A6E),
    error: Color(0xFFDC2626),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF991B1B),
    surface: _stone50,
    onSurface: _stone900,
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: _stone100,
    surfaceContainer: _stone200,
    surfaceContainerHigh: _stone300,
    surfaceContainerHighest: _stone400,
    outline: _stone400,
    outlineVariant: _stone200,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: _stone900,
    onInverseSurface: _stone100,
    inversePrimary: _orange400,
  );

  // ── Dark color scheme ────────────────────────────────────────────────────
  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _orange400,
    onPrimary: Color(0xFF1C0700),
    primaryContainer: Color(0xFF7C2D12),
    onPrimaryContainer: _orange100,
    secondary: Color(0xFF94A3B8),
    onSecondary: Color(0xFF1E293B),
    secondaryContainer: Color(0xFF1E293B),
    onSecondaryContainer: Color(0xFFCBD5E1),
    tertiary: Color(0xFF38BDF8),
    onTertiary: Color(0xFF082F49),
    tertiaryContainer: Color(0xFF0C4A6E),
    onTertiaryContainer: Color(0xFFE0F2FE),
    error: Color(0xFFF87171),
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF991B1B),
    onErrorContainer: Color(0xFFFEE2E2),
    surface: _stone900,
    onSurface: _stone50,
    surfaceContainerLowest: _stone950,
    surfaceContainerLow: _stone900,
    surfaceContainer: _stone800,
    surfaceContainerHigh: _stone700,
    surfaceContainerHighest: _stone500,
    outline: _stone500,
    outlineVariant: _stone700,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: _stone100,
    onInverseSurface: _stone900,
    inversePrimary: _orange600,
  );

  // ── Typography ───────────────────────────────────────────────────────────
  static TextTheme _buildTextTheme(TextTheme base) =>
      GoogleFonts.dmSansTextTheme(base).copyWith(
        displayLarge: GoogleFonts.dmSans(
            fontSize: 57, fontWeight: FontWeight.w400, letterSpacing: -0.25),
        displayMedium: GoogleFonts.dmSans(
            fontSize: 45, fontWeight: FontWeight.w400),
        displaySmall: GoogleFonts.dmSans(
            fontSize: 36, fontWeight: FontWeight.w400),
        headlineLarge: GoogleFonts.dmSans(
            fontSize: 32, fontWeight: FontWeight.w600),
        headlineMedium: GoogleFonts.dmSans(
            fontSize: 28, fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.dmSans(
            fontSize: 24, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.dmSans(
            fontSize: 22, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.dmSans(
            fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.15),
        titleSmall: GoogleFonts.dmSans(
            fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
        bodyLarge: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w400),
        bodySmall: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w400),
        labelLarge: GoogleFonts.dmSans(
            fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
        labelMedium: GoogleFonts.dmSans(
            fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
        labelSmall: GoogleFonts.dmSans(
            fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
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
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  static CardTheme _cardTheme(ColorScheme cs) => CardTheme(
        elevation: 0,
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant, width: 1),
        ),
        margin: EdgeInsets.zero,
      );

  static FilledButtonThemeData _filledButtonTheme(ColorScheme cs) =>
      FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle:
              GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      );

  static AppBarTheme _appBarTheme(ColorScheme cs) => AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      );

  // ── Public theme builders ────────────────────────────────────────────────
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
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      scaffoldBackgroundColor: cs.surface,
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cs.surfaceContainerLow,
        indicatorColor: cs.primaryContainer,
        selectedIconTheme: IconThemeData(color: cs.primary),
        selectedLabelTextStyle: GoogleFonts.dmSans(
            fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary),
        unselectedIconTheme:
            IconThemeData(color: cs.onSurface.withValues(alpha: 0.6)),
        unselectedLabelTextStyle: GoogleFonts.dmSans(
            fontSize: 12,
            color: cs.onSurface.withValues(alpha: 0.6)),
      ),
    );
  }

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
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      scaffoldBackgroundColor: cs.surface,
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cs.surfaceContainerLow,
        indicatorColor: cs.primaryContainer,
        selectedIconTheme: IconThemeData(color: cs.primary),
        selectedLabelTextStyle: GoogleFonts.dmSans(
            fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary),
        unselectedIconTheme: IconThemeData(
            color: cs.onSurface.withValues(alpha: 0.6)),
        unselectedLabelTextStyle: GoogleFonts.dmSans(
            fontSize: 12,
            color: cs.onSurface.withValues(alpha: 0.6)),
      ),
    );
  }
}
