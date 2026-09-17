import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Garam tetap lintas flavor — 1 perangkat = 1 hash yang sama di app
/// user maupun admin, agar ban perangkat cocok di kedua sisi.
const String _deviceSalt = 'jadwal-pintar-device-v1';

/// Nilai ANDROID_ID yang dikenal rusak — diperlakukan sebagai tak terbaca.
const String _brokenAndroidId = '9774d56d682e549e';

/// SHA-256(ANDROID_ID | salt) atau null bila tak terbaca.
/// Tahan hapus-data & reinstall; berubah hanya via factory reset / ganti
/// HP / beda signing-key. Tanpa permission tambahan.
Future<String?> androidIdHash() async {
  if (!Platform.isAndroid) return null;
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    final id = info.id;
    if (id.isEmpty || id == _brokenAndroidId) return null;
    return sha256.convert(utf8.encode('$id|$_deviceSalt')).toString();
  } catch (_) {
    return null;
  }
}

/// Info perangkat non-unik untuk label admin (tanpa permission).
Future<String> deviceLabel() async {
  if (!Platform.isAndroid) return '-';
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    return '${info.manufacturer} ${info.model}'.trim();
  } catch (_) {
    return '-';
  }
}
