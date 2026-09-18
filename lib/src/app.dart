import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin/theme.dart';
import 'core/flavor.dart';
import 'screens/admin_home.dart';
import 'screens/user_home.dart';
import 'user/user_theme_provider.dart';

/// Root widget monorepo. Satu codebase, dua flavor via `--flavor` + `--target`.
class JadwalPintarApp extends ConsumerWidget {
  const JadwalPintarApp({super.key, required this.flavor});

  final AppFlavor flavor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (flavor == AppFlavor.admin) {
      _applySystemBars(
        MediaQuery.platformBrightnessOf(context) == Brightness.light,
      );
      return MaterialApp(
        title: flavor.title,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const AdminHomeScreen(),
      );
    }
    final userTheme = ref.watch(userThemeProvider);
    _applySystemBars(userTheme.isLight);
    return MaterialApp(
      title: flavor.title,
      debugShowCheckedModeBanner: false,
      theme: userTheme.themeData,
      home: const UserHomeScreen(),
    );
  }
}

/// Layar diagnostik bila inisialisasi native gagal SEBELUM runApp.
/// Tanpa ini kegagalan init = layar hitam tanpa pesan.
class BootErrorScreen extends StatelessWidget {
  const BootErrorScreen({super.key, required this.flavor, required this.error});

  final AppFlavor flavor;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.error_outline, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Gagal memulai aplikasi',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'Flavor: ${flavor.name} • v3.0.0+3',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SelectableText('$error'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Status/nav bar transparan menyatu tema (edge-to-edge).
/// Dipanggil tiap build agar ikon bar mengikuti terang/gelap tema.
void _applySystemBars(bool isLight) {
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          isLight ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isLight ? Brightness.dark : Brightness.light,
    ),
  );
}

/// Status koneksi Firebase untuk layar bootstrap Fase 0.
class FirebaseStatusCard extends StatelessWidget {  const FirebaseStatusCard({super.key, required this.flavor});

  final AppFlavor flavor;

  @override
  Widget build(BuildContext context) {
    final ok = Firebase.apps.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              size: 40,
              color: ok ? scheme.primary : scheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              ok ? 'Firebase: terhubung' : 'Firebase: belum siap',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Flavor: ${flavor.name} • v3.0.0+3',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
