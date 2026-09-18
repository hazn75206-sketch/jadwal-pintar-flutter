import 'dart:async';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/core/flavor.dart';
import 'src/core/sfx.dart';

/// Entrypoint flavor USER (`--flavor user --target lib/main_user.dart`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Semua init dibungkus: kegagalan SEBELUM runApp = layar hitam tanpa
  // pesan. Tangkap lalu tampilkan sebagai layar diagnostik.
  try {
    await Firebase.initializeApp();
    try {
      await AndroidAlarmManager.initialize();
    } catch (_) {}
    unawaited(Sfx.init());
  } catch (e) {
    runApp(BootErrorScreen(flavor: AppFlavor.user, error: e));
    return;
  }
  runApp(const ProviderScope(child: JadwalPintarApp(flavor: AppFlavor.user)));
}
