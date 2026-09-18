import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/core/flavor.dart';
import 'src/core/sfx.dart';

/// Entrypoint flavor ADMIN (`--flavor admin --target lib/main_admin.dart`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    unawaited(Sfx.init());
  } catch (e) {
    runApp(BootErrorScreen(flavor: AppFlavor.admin, error: e));
    return;
  }
  runApp(const ProviderScope(child: JadwalPintarApp(flavor: AppFlavor.admin)));
}
