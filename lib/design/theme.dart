import 'package:flutter/material.dart';

abstract final class StudioTokens {
  static const pdf = Color(0xffba3e43);
  static const scan = Color(0xff087f78);
  static const photo = Color(0xff5753bd);
  static const pack = Color(0xff976000);
  static const darkPdf = Color(0xffffb3b5);
  static const darkScan = Color(0xff72d9cc);
  static const darkPhoto = Color(0xffc8bfff);
  static const darkPack = Color(0xffffcf7b);
  static const spacing = 16.0;
  static const radius = 20.0;
  static ThemeData theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: photo,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'StudioRoboto',
      fontFamilyFallback: const ['StudioNotoBengali'],
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xfff7f8fc)
          : const Color(0xff12141c),
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.all(16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}
