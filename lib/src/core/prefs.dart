import 'package:shared_preferences/shared_preferences.dart';

/// Kunci penyimpanan lokal — cerminan 1:1 localStorage WebView native agar
/// data pengguna lama terbaca mulus setelah migrasi ke Flutter.
abstract final class PrefKeys {
  static const String schedule = 'jadwal_v2';
  static const String locked = 'jadwal_locked';
  static const String lastSync = 'jadwal_last_sync';
  static const String customPhoto = 'custom_profile_photo';
  static const String startTime = 'jadwal_start_time';
  static const String loginSkipped = 'login_prompt_skipped';
  static const String themePreset = 'jadwal_theme_preset';
  static const String themeLight = 'jadwal_theme_light';
  static const String themeCustomColor = 'jadwal_theme_custom_color';
  static const String sfxEnabled = 'sfx_enabled';

  static String accessLatch(String uid) => 'access_latched_$uid';
  static String banLatch(String hash) => 'ban_latched_$hash';
  static const String protectionOn = 'device_protection_on';

  static const String cachedUid = 'cached_uid';
  static const String cachedName = 'cached_name';
  static const String cachedEmail = 'cached_email';
  static const String cachedPhoto = 'cached_photo';
}

/// Pembungkus tipis SharedPreferences agar call-site tetap rapi.
class LocalPrefs {
  LocalPrefs._(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalPrefs._(prefs);
  }

  String? getString(String key) => _prefs.getString(key);
  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);
  Future<bool> remove(String key) => _prefs.remove(key);
  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;
  Future<bool> setBool(String key, bool value) =>
      _prefs.setBool(key, value);
}
