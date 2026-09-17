import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';
import 'connectivity_service.dart';
import 'database_service.dart';
import 'device_id.dart';
import 'models.dart';
import 'prefs.dart';
import 'storage_service.dart';

/// Service tunggal per aplikasi (dibuat sekali, dipakai semua layar).
final authServiceProvider = Provider<AuthService>((_) => AuthService());
final databaseProvider = Provider<DatabaseService>((_) => DatabaseService());
final storageServiceProvider =
    Provider<StorageService>((_) => StorageService());
final connectivityServiceProvider =
    Provider<ConnectivityService>((_) => ConnectivityService());
final prefsProvider =
    FutureProvider<LocalPrefs>((_) => LocalPrefs.load());

/// Sesi Firebase realtime (null = belum login). Tahan restart & offline.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).state,
);

/// Hash SHA-256 ANDROID_ID (null = tak terbaca → izinkan + tandai).
final deviceHashProvider =
    FutureProvider<String?>((_) => androidIdHash());

/// Konfigurasi remote realtime (maintenance/update/popup/proteksi).
final appConfigProvider = StreamProvider<AppConfig>(
  (ref) => ref.watch(databaseProvider).appConfigStream(),
);

/// Status koneksi gabungan (jaringan + socket database).
final onlineProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityServiceProvider).onlineStream,
);

/// Daftar profil pengguna (admin).
final profilesProvider = StreamProvider<Map<String, UserProfile>>(
  (ref) => ref.watch(databaseProvider).profilesStream(),
);

/// Peta userAccess (admin).
final accessMapProvider = StreamProvider<Map<String, UserAccess>>(
  (ref) => ref.watch(databaseProvider).accessMapStream(),
);

/// Daftar perangkat banned (admin).
final bansProvider = StreamProvider<Map<String, DeviceBan>>(
  (ref) => ref.watch(databaseProvider).bansStream(),
);
