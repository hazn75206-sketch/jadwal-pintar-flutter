import 'package:flutter/material.dart';

/// Preset tema cermin `themePresets` di style/script.js native.
enum ThemePreset {
  blue,
  emerald,
  purple,
  ruby,
  amber,
  sky,
  pink,
  glass,
  custom,
}

ThemePreset themePresetFromName(String? name) {
  for (final preset in ThemePreset.values) {
    if (preset.name == name) return preset;
  }
  return ThemePreset.blue;
}

class _PresetColors {
  const _PresetColors({
    required this.primary,
    required this.darkBg,
    required this.darkCard,
  });

  final Color primary;
  final Color darkBg;
  final Color darkCard;
}

/// Warna tiap preset (diambil dari style.css native).
_PresetColors _colorsFor(ThemePreset preset, Color custom) {
  switch (preset) {
    case ThemePreset.blue:
      return const _PresetColors(
        primary: Color(0xFF007AFF),
        darkBg: Colors.black,
        darkCard: Color(0xB31C1C1E),
      );
    case ThemePreset.emerald:
      return const _PresetColors(
        primary: Color(0xFF10B981),
        darkBg: Color(0xFF080C16),
        darkCard: Color(0xCC0F172A),
      );
    case ThemePreset.purple:
      return const _PresetColors(
        primary: Color(0xFF8B5CF6),
        darkBg: Color(0xFF0C0816),
        darkCard: Color(0xCC1C1428),
      );
    case ThemePreset.ruby:
      return const _PresetColors(
        primary: Color(0xFFEF4444),
        darkBg: Color(0xFF160808),
        darkCard: Color(0xCC281414),
      );
    case ThemePreset.amber:
      return const _PresetColors(
        primary: Color(0xFFF59E0B),
        darkBg: Color(0xFF161008),
        darkCard: Color(0xCC281E10),
      );
    case ThemePreset.sky:
      return const _PresetColors(
        primary: Color(0xFF0EA5E9),
        darkBg: Color(0xFF080C16),
        darkCard: Color(0xCC0F172A),
      );
    case ThemePreset.pink:
      return const _PresetColors(
        primary: Color(0xFFEC4899),
        darkBg: Color(0xFF160810),
        darkCard: Color(0xCC28101C),
      );
    case ThemePreset.glass:
      return const _PresetColors(
        primary: Color(0xFF8B5CF6),
        darkBg: Color(0x26000000),
        darkCard: Color(0x0FFFFFFF),
      );
    case ThemePreset.custom:
      return _PresetColors(
        primary: custom,
        darkBg: Colors.black,
        darkCard: const Color(0xB31C1C1E),
      );
  }
}

const Map<ThemePreset, String> presetLabels = <ThemePreset, String>{
  ThemePreset.blue: 'Biru',
  ThemePreset.emerald: 'Emerald',
  ThemePreset.purple: 'Ungu',
  ThemePreset.ruby: 'Merah',
  ThemePreset.amber: 'Emas',
  ThemePreset.sky: 'Sky',
  ThemePreset.pink: 'Pink',
  ThemePreset.glass: 'Glass',
  ThemePreset.custom: 'Custom',
};

ThemeData buildUserTheme({
  required ThemePreset preset,
  required Color customColor,
  required bool isLight,
}) {
  final colors = _colorsFor(preset, customColor);
  if (isLight) {
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }
  final scheme = ColorScheme.fromSeed(
    seedColor: colors.primary,
    brightness: Brightness.dark,
    surface: colors.darkCard,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: colors.darkBg,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: colors.darkBg,
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      color: colors.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.primary,
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
    ),
  );
}
