import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/prefs.dart';
import 'theme.dart';

/// State tema user (cermin localStorage tema native; tanpa reload).
class UserThemeState {
  const UserThemeState({
    required this.preset,
    required this.customColor,
    required this.isLight,
  });

  final ThemePreset preset;
  final Color customColor;
  final bool isLight;

  ThemeData get themeData => buildUserTheme(
        preset: preset,
        customColor: customColor,
        isLight: isLight,
      );
}

class UserThemeController extends StateNotifier<UserThemeState> {
  UserThemeController(this._ref)
      : super(const UserThemeState(
          preset: ThemePreset.blue,
          customColor: Color(0xFF007AFF),
          isLight: false,
        )) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    try {
      final prefs = await _ref.read(prefsProvider.future);
      state = UserThemeState(
        preset: themePresetFromName(
            prefs.getString(PrefKeys.themePreset)),
        customColor: _parseColor(
            prefs.getString(PrefKeys.themeCustomColor)),
        isLight:
            prefs.getString(PrefKeys.themeLight) == '1',
      );
    } catch (_) {}
  }

  Future<void> setPreset(ThemePreset preset) async {
    state = UserThemeState(
      preset: preset,
      customColor: state.customColor,
      isLight: state.isLight,
    );
    try {
      final prefs = await _ref.read(prefsProvider.future);
      await prefs.setString(PrefKeys.themePreset, preset.name);
    } catch (_) {}
  }

  Future<void> setCustomColor(Color color) async {
    final hex =
        '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    state = UserThemeState(
      preset: ThemePreset.custom,
      customColor: color,
      isLight: state.isLight,
    );
    try {
      final prefs = await _ref.read(prefsProvider.future);
      await prefs.setString(PrefKeys.themePreset, 'custom');
      await prefs.setString(PrefKeys.themeCustomColor, hex);
    } catch (_) {}
  }

  Future<void> setLight(bool value) async {
    state = UserThemeState(
      preset: state.preset,
      customColor: state.customColor,
      isLight: value,
    );
    try {
      final prefs = await _ref.read(prefsProvider.future);
      await prefs.setString(
          PrefKeys.themeLight, value ? '1' : '0');
    } catch (_) {}
  }

  static Color _parseColor(String? hex) {
    if (hex == null) return const Color(0xFF007AFF);
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final value = int.tryParse('FF$clean', radix: 16);
      if (value != null) return Color(value);
    }
    return const Color(0xFF007AFF);
  }
}

final userThemeProvider =
    StateNotifierProvider<UserThemeController, UserThemeState>(
  (ref) => UserThemeController(ref),
);
