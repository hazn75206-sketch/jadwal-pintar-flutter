import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

/// Channel ke MainActivity untuk ANDROID_ID asli (Settings.Secure).
/// device_info_plus TIDAK menyediakan ANDROID_ID (`id` di sana = Build.ID
/// yang sama di semua HP se-OS-build) — jadi wajib lewat channel ini.
const MethodChannel _deviceChannel = MethodChannel('jadwalpintar/device');

/// Salt HARUS sama persis dengan aplikasi native agar kunci deviceBans
/// cocok lintas native ↔ Flutter: native user = "|com.jadwalpintar.app".
/// (App admin tidak memakai enforcement perangkat; salt admin tidak dipakai.)
const String _userSalt = '|com.jadwalpintar.app';

/// Nilai ANDROID_ID yang dikenal rusak — diperlakukan sebagai tak terbaca.
const String _brokenAndroidId = '9774d56d682e549e';

Future<String?> _androidId() async {
  if (!Platform.isAndroid) return null;
  try {
    final id = await _deviceChannel.invokeMethod<String>('getAndroidId');
    if (id == null || id.isEmpty || id == _brokenAndroidId) return null;
    return id;
  } catch (_) {
    return null;
  }
}

/// SHA-256(ANDROID_ID | salt) atau null bila tak terbaca.
/// Sama persis dengan getAndroidIdHash() native → ban perangkat lama tetap
/// berlaku, dan 1 perangkat = 1 hash stabil (tahan hapus-data & reinstall;
/// berubah hanya via factory reset / ganti HP / beda signing-key).
Future<String?> androidIdHash() async {
  final id = await _androidId();
  if (id == null) return null;
  return sha256.convert(utf8.encode('$id$_userSalt')).toString();
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
