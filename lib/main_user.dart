import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/core/flavor.dart';

/// Entrypoint flavor USER (`--flavor user --target lib/main_user.dart`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const JadwalPintarApp(flavor: AppFlavor.user));
}
