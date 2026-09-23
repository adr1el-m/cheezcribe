import 'package:flutter/material.dart';

/// Paperazzi industrial design tokens.
///
/// Blue is reserved for actions, active states, links, and detection
/// overlays. Status colors are muted so they read as instrument indicators,
/// not alerts.
abstract final class Pz {
  // Surfaces
  static const bg = Color(0xFFF7F8F8);
  static const surface2 = Color(0xFFF0F2F3);
  static const paper = Color(0xFFFBFAF7);
  static const card = Color(0xFFFDFDFC);
  static const dark = Color(0xFF121820);
  static const darkRaised = Color(0xFF1A222C);

  // Brand
  static const blue = Color(0xFF1769E8);
  static const deepBlue = Color(0xFF123F8C);
  static const navy = Color(0xFF101B2D);
  static const steel = Color(0xFF65758A);
  static const graphite = Color(0xFF252A31);
  static const muted = Color(0xFF8C97A5);

  // Lines
  static const line = Color(0xFFDDE1E5);
  static const lineStrong = Color(0xFFC6CDD5);
  static const lineDark = Color(0xFF2A3440);

  // Status
  static const verified = Color(0xFF3F8A6A);
  static const review = Color(0xFFC98624);
  static const error = Color(0xFFB84A4A);
  static const inactive = Color(0xFF9AA4B1);

  // Detection overlays (muted)
  static const overlayText = blue;
  static const overlayDrawing = Color(0xFF6B5FA6);

  // Geometry
  static const rCard = 10.0;
  static const rButton = 8.0;
  static const rChip = 6.0;
  static const gutter = 20.0;

  static const tabular = [FontFeature.tabularFigures()];

  // Type scale
  static const screenTitle = TextStyle(
      fontSize: 28,
      height: 1.15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      color: navy);
  static const sectionTitle = TextStyle(
      fontSize: 18,
      height: 1.25,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: navy);
  static const cardTitle = TextStyle(
      fontSize: 15, height: 1.3, fontWeight: FontWeight.w600, color: navy);
  static const body = TextStyle(fontSize: 14, height: 1.45, color: graphite);
  static const meta = TextStyle(
      fontSize: 12.5, height: 1.35, color: steel, fontFeatures: tabular);
  static const label = TextStyle(
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.1,
      color: steel);
  static const value = TextStyle(
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: navy,
      fontFeatures: tabular);
  static const figure = TextStyle(
      fontSize: 22,
      height: 1.1,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      color: navy,
      fontFeatures: tabular);

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.light,
    ).copyWith(
      primary: blue,
      onPrimary: Colors.white,
      surface: card,
      onSurface: navy,
      outline: lineStrong,
      error: error,
    );
    final buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(rButton));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      splashFactory: InkRipple.splashFactory,
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: blue),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surface2,
          elevation: 0,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: buttonShape,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          side: const BorderSide(color: lineStrong),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: buttonShape,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blue,
          shape: buttonShape,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        labelStyle: meta,
        hintStyle: const TextStyle(fontSize: 14, color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rButton),
          borderSide: const BorderSide(color: lineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rButton),
          borderSide: const BorderSide(color: lineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rButton),
          borderSide: const BorderSide(color: blue, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(rCard)),
        titleTextStyle: sectionTitle,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(rCard))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: navy,
        contentTextStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rButton)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? blue : lineStrong),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}
