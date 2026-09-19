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
        darkBg: Color(0xFF0A0E1A),
        darkCard: Color(0x1CFFFFFF),
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
  // Glass preset: liquid glass 100% — light & dark varian berbeda.
  if (preset == ThemePreset.glass) {
    if (isLight) {
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF8B5CF6),
        brightness: Brightness.light,
      );
      return ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F6FB),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Color(0xFFF4F6FB),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: const Color(0x9CFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0x1A000000)),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xF0FFFFFF),
          barrierColor: Color(0x33000000),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          modalBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: .72),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0x14000000)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0x14000000)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.white.withValues(alpha: .88),
          foregroundColor: scheme.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      );
    }
    // dark glass
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8B5CF6),
      brightness: Brightness.dark,
      surface: const Color(0x1CFFFFFF),
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0A0E1A),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Color(0xFF0A0E1A),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: const Color(0x1CFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0x33FFFFFF)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xCC1A1D2E),
        barrierColor: Color(0x66000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: .07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary.withValues(alpha: .88),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
  final colors = _colorsFor(preset, customColor);
  if (isLight) {
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .45)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: .45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
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
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.primary,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}
