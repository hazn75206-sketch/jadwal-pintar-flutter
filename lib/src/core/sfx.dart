import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prefs.dart';

/// Efek suara — aset reuse dari aplikasi native (`assets/sfx/*.wav`).
class Sfx {
  Sfx._();

  static final AudioPlayer _player = AudioPlayer();
  static bool _enabled = true;
  static bool _loaded = false;

  static bool get enabled => _enabled;

  static Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(PrefKeys.sfxEnabled) ?? true;
    } catch (_) {
      _enabled = true;
    }
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PrefKeys.sfxEnabled, value);
    } catch (_) {}
  }

  /// name: click, success, error, pop, swoosh, splash.
  static Future<void> play(String name) async {
    if (!_enabled) return;
    try {
      await _player.play(AssetSource('sfx/sfx_$name.wav'));
    } catch (_) {}
  }
}
