import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth_service.dart';
import '../core/database_service.dart';
import '../core/device_id.dart';
import '../core/models.dart';
import '../core/prefs.dart';
import '../core/providers.dart';
import '../core/sfx.dart';
import 'schedule_provider.dart';

/// Status sesi cermin alur native (gate login, blokir, kunci device).
enum SessionStatus {
  /// Boot / memverifikasi.
  boot,

  /// Belum login & belum lewati: tampilkan gate login.
  gate,

  /// Login aktif (online maupun offline).
  loggedIn,

  /// Akun/perangkat diblokir: popup + jadwal dikosongkan.
  blocked,

  /// Proteksi device ON + banned: kunci total sejak boot.
  locked,
}

class SessionState {
  const SessionState({
    required this.status,
    this.name = '',
    this.email = '',
    this.photo = '',
    this.loginSkipped = false,
    this.blockedTitle = '',
    this.blockedMessage = '',
  });

  final SessionStatus status;
  final String name;
  final String email;
  final String photo;
  final bool loginSkipped;
  final String blockedTitle;
  final String blockedMessage;

  SessionState copyWith({
    SessionStatus? status,
    String? name,
    String? email,
    String? photo,
    bool? loginSkipped,
    String? blockedTitle,
    String? blockedMessage,
  }) {
    return SessionState(
      status: status ?? this.status,
      name: name ?? this.name,
      email: email ?? this.email,
      photo: photo ?? this.photo,
      loginSkipped: loginSkipped ?? this.loginSkipped,
      blockedTitle: blockedTitle ?? this.blockedTitle,
      blockedMessage: blockedMessage ?? this.blockedMessage,
    );
  }
}

/// Orkestrasi sesi + gate akses realtime (cermin MainActivity native).
class SessionController extends StateNotifier<SessionState> {
  SessionController(this._ref)
      : super(const SessionState(status: SessionStatus.boot)) {
    _boot();
  }

  final Ref _ref;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<UserAccess?>? _accessSub;
  StreamSubscription<DeviceBan?>? _banSub;
  StreamSubscription<AppConfig>? _configSub;
  Timer? _gateTimer;
  bool _gateResolved = false;
  bool _accessReady = false;
  bool _banReady = false;
  String? _deviceHash;
  bool _protectionOn = false;
  /// UID yang jadwal cloud-nya sudah dipulihkan sekali pada sesi login ini.
  /// Cegah restore berulang (P1); reset saat logout/ganti akun.
  String? _restoredUid;

  AuthService get _auth => _ref.read(authServiceProvider);
  DatabaseService get _db => _ref.read(databaseProvider);

  Future<LocalPrefs> get _prefs async =>
      _ref.read(prefsProvider.future);

  Future<void> _boot() async {
    _deviceHash = await androidIdHash();
    final prefs = await _prefs;
    _protectionOn =
        prefs.getBool(PrefKeys.protectionOn, fallback: false);
    final skipped =
        prefs.getString(PrefKeys.loginSkipped) == '1';
    state = state.copyWith(loginSkipped: skipped);

    // Latch lokal dulu (instan, offline-safe) sebelum cek Firebase.
    if (_isBanLatchedSync(prefs) && _protectionOn) {
      state = state.copyWith(status: SessionStatus.locked);
      await Sfx.play('error');
      return;
    }
    _authSub = _auth.state.listen(_onAuthChanged);
    // Status awal sinkron bila sesi sudah ada.
    _onAuthChanged(_auth.current);
  }

  bool _isBanLatchedSync(LocalPrefs prefs) {
    final hash = _deviceHash;
    if (hash == null || hash.isEmpty) return false;
    return prefs.getBool(PrefKeys.banLatch(hash), fallback: false);
  }

  Future<bool> _isBanLatched() async =>
      _isBanLatchedSync(await _prefs);

  Future<bool> _isAccessLatched(String uid) async {
    final prefs = await _prefs;
    return prefs.getBool(PrefKeys.accessLatch(uid), fallback: false);
  }

  void _onAuthChanged(User? user) {
    _detachGates();
    _gateResolved = false;
    _accessReady = false;
    _banReady = false;
    if (user == null) {
      _applySignedOut();
      return;
    }
    _cacheProfile(user);
    // Profil + presence + marker offline (cermin writeUserProfile native).
    // Tanpa ini admin tidak bisa memblokir perangkat (hash tak tercatat).
    unawaited(_writeProfile(user));
    // Offline: langsung tampil dari cache tanpa menunggu gate.
    _checkOffline().then((offline) {
      if (offline) {
        _gateResolved = true;
        _applyLoggedIn();
        return;
      }
      _attachGates(user.uid);
      _armGateTimeout();
    });
  }

  Future<bool> _checkOffline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return !results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  void _attachGates(String uid) {
    final hash = _deviceHash;
    _accessSub = _db.userAccessStream(uid).listen((access) async {
      if (access != null && !access.enabled) {
        await _enforce('account', null, null);
      } else if (await _isAccessLatched(uid)) {
        await _clearAccessLatch(uid);
        _gateResolved = true;
        _applyLoggedIn();
      } else {
        _accessReady = true;
        _maybeResolveGate();
      }
    }, onError: (_) => _resolveGateIfClean());
    if (hash != null && hash.isNotEmpty) {
      _banSub = _db.deviceBanStream(hash).listen((ban) async {
        if (ban != null && ban.banned) {
          final prefs = await _prefs;
          await prefs.setBool(PrefKeys.banLatch(hash), true);
          _gateResolved = true;
          await _enforce('device', null, null);
        } else if (await _isBanLatched()) {
          final p = await _prefs;
          await p.remove(PrefKeys.banLatch(hash));
          _gateResolved = true;
          _applyLoggedIn();
        } else {
          _banReady = true;
          _maybeResolveGate();
        }
      }, onError: (_) => _resolveGateIfClean());
    } else {
      _banReady = true;
    }
    _configSub = _db.appConfigStream().listen((config) async {
      final on = config.protection.enabled;
      _protectionOn = on;
      try {
        final prefs = await _prefs;
        await prefs.setBool(PrefKeys.protectionOn, on);
      } catch (_) {}
      if (on && await _isBanLatched()) {
        state = state.copyWith(status: SessionStatus.locked);
      } else if (!on &&
          state.status == SessionStatus.locked &&
          !await _isBanLatched()) {
        _applyLoggedIn();
      } else if (!on &&
          state.status == SessionStatus.locked &&
          await _isBanLatched()) {
        // Proteksi dimatikan tapi ban ada: tetap blokir akun.
        await _enforce('device', null, null);
      }
    });
  }

  void _armGateTimeout() {
    _gateTimer?.cancel();
    _gateTimer = Timer(const Duration(seconds: 10), () async {
      if (_gateResolved) return;
      if (!await _isBanLatched() &&
          !await _isAccessLatched(_auth.current?.uid ?? '')) {
        _gateResolved = true;
        _applyLoggedIn();
      }
    });
  }

  /// Gate lolos bila kedua stream pertama sudah memberi jawaban bersih.
  void _maybeResolveGate() {
    if (_gateResolved) return;
    if (_accessReady && _banReady) {
      _gateResolved = true;
      _applyLoggedIn();
    }
  }

  Future<void> _resolveGateIfClean() async {
    if (_gateResolved) return;
    if (!await _isBanLatched() &&
        !await _isAccessLatched(_auth.current?.uid ?? '')) {
      _gateResolved = true;
      _applyLoggedIn();
    }
  }

  void _detachGates() {
    _gateTimer?.cancel();
    _gateTimer = null;
    _restoredUid = null;
    _accessSub?.cancel();
    _banSub?.cancel();
    _configSub?.cancel();
    _accessSub = null;
    _banSub = null;
    _configSub = null;
  }

  /// Tulis profil ke userProfiles + tandai online (cermin native).
  /// set() penuh seperti native (bukan update) agar field usang terhapus.
  Future<void> _writeProfile(User user) async {
    try {
      final uid = user.uid;
      final now = DateTime.now().millisecondsSinceEpoch;
      final createdAt =
          user.metadata.creationTime?.millisecondsSinceEpoch ?? now;
      await _db.writeProfile(uid, <String, Object?>{
        'name': (user.displayName?.isNotEmpty ?? false)
            ? user.displayName!
            : (await _prefs).getString(PrefKeys.cachedName) ?? '',
        'email': (user.email?.isNotEmpty ?? false)
            ? user.email!
            : (await _prefs).getString(PrefKeys.cachedEmail) ?? '',
        'createdAt': createdAt,
        'lastLoginAt': now,
        'lastSeenAt': now,
        'online': true,
        'appVersion': '3.0.0+3',
        'deviceModel': await deviceLabel(),
        if (_deviceHash != null && _deviceHash!.isNotEmpty)
          'deviceIdHash': _deviceHash!
        else
          'deviceIdMissing': true,
      });
      await _db.updatePresence(uid, true);
      await _db.armOfflineMarker(uid);
    } catch (_) {}
  }

  void _cacheProfile(User user) {
    _prefs.then((prefs) {
      prefs.setString(PrefKeys.cachedUid, user.uid);
      prefs.setString(
          PrefKeys.cachedName, user.displayName ?? '');
      prefs.setString(PrefKeys.cachedEmail, user.email ?? '');
      prefs.setString(
          PrefKeys.cachedPhoto, user.photoURL ?? '');
    }).ignore();
  }

  Future<void> _applyLoggedIn() async {
    final user = _auth.current;
    final prefs = await _prefs;
    final name = user?.displayName ??
        prefs.getString(PrefKeys.cachedName) ??
        '';
    final email =
        user?.email ?? prefs.getString(PrefKeys.cachedEmail) ?? '';
    final photo = (user?.photoURL?.isNotEmpty ?? false)
        ? user!.photoURL!
        : (prefs.getString(PrefKeys.cachedPhoto) ?? '');
    state = state.copyWith(
      status: SessionStatus.loggedIn,
      name: name,
      email: email,
      photo: photo,
    );
    // P1: pulihkan jadwal cloud sekali per login bila online.
    // Tanpa ini install baru + login akun berisi = jadwal kosong.
    final uid = user?.uid;
    if (uid != null && uid.isNotEmpty && _restoredUid != uid) {
      _restoredUid = uid;
      _checkOffline().then((offline) {
        if (!offline) {
          unawaited(
            _ref.read(scheduleProvider.notifier).restoreFromCloud(),
          );
        }
      });
    }
  }

  void _applySignedOut() {
    final skipped = state.loginSkipped;
    if (state.status == SessionStatus.locked) return;
    state = SessionState(
      status: skipped ? SessionStatus.loggedIn : SessionStatus.gate,
      loginSkipped: skipped,
    );
  }

  /// Penegakan blokir: latch + hapus jadwal lokal + popup.
  /// reason: `account` atau `device`. Cloud TIDAK dihapus.
  Future<void> _enforce(
    String reason,
    String? title,
    String? message,
  ) async {
    final prefs = await _prefs;
    final uid = _auth.current?.uid ?? '';
    if (reason == 'account' && uid.isNotEmpty) {
      await prefs.setBool(PrefKeys.accessLatch(uid), true);
    }
    final hash = _deviceHash;
    if (reason == 'device' && hash != null && hash.isNotEmpty) {
      await prefs.setBool(PrefKeys.banLatch(hash), true);
    }
    await _ref.read(scheduleProvider.notifier).wipeLocal();
    await _auth.signOutGoogleOnly();
    await Sfx.play('error');
    if (reason == 'device' && _protectionOn) {
      state = state.copyWith(status: SessionStatus.locked);
      return;
    }
    state = state.copyWith(
      status: SessionStatus.blocked,
      blockedTitle: title ??
          (reason == 'device' ? 'Perangkat diblokir' : 'Akses akun dinonaktifkan'),
      blockedMessage: message ??
          (reason == 'device'
              ? 'Perangkat ini tidak diizinkan mengakses Jadwal Pintar. Hubungi administrator.'
              : 'Akun Anda dinonaktifkan. Jadwal lokal telah dihapus. Hubungi administrator.'),
    );
  }

  Future<void> _clearAccessLatch(String uid) async {
    try {
      final prefs = await _prefs;
      await prefs.remove(PrefKeys.accessLatch(uid));
    } catch (_) {}
  }

  // ---------- Aksi UI ----------

  Future<void> skipLogin() async {
    try {
      final prefs = await _prefs;
      await prefs.setString(PrefKeys.loginSkipped, '1');
    } catch (_) {}
    state = state.copyWith(
      status: SessionStatus.loggedIn,
      loginSkipped: true,
    );
  }

  Future<String?> loginWithGoogle() async {
    try {
      await _auth.signInWithGoogle();
      // P4: tolak login di perangkat banned (aturan user) — walau akunnya
      // berbeda. deviceBans hanya bisa dibaca saat login (rules),
      // jadi cek sekali tepat setelah sign-in berhasil.
      final hash = _deviceHash;
      if (hash != null && hash.isNotEmpty) {
        DeviceBan? ban;
        try {
          ban = await _db.loadDeviceBan(hash).timeout(
                const Duration(seconds: 8),
                onTimeout: () => null,
              );
        } catch (_) {
          ban = null;
        }
        if (ban != null && ban.banned) {
          final prefs = await _prefs;
          await prefs.setBool(PrefKeys.banLatch(hash), true);
          await _ref.read(scheduleProvider.notifier).wipeLocal();
          _detachGates();
          await _auth.signOut();
          _restoredUid = null;
          state = SessionState(
            status: SessionStatus.gate,
            loginSkipped: state.loginSkipped,
          );
          await Sfx.play('error');
          return 'Tidak dapat login karena perangkat Anda telah diblokir.';
        }
      }
      return null;
    } catch (e) {
      await Sfx.play('error');
      return '$e'.replaceFirst('Exception: ', '');
    }
  }

  Future<void> logout() async {
    _detachGates();
    try {
      final uid = _auth.current?.uid ?? '';
      if (uid.isNotEmpty) {
        await _db.updatePresence(uid, false).timeout(
          const Duration(seconds: 5),
          onTimeout: () async {},
        );
      }
    } catch (_) {}
    await _auth.signOut();
    try {
      final prefs = await _prefs;
      await prefs.remove(PrefKeys.customPhoto);
    } catch (_) {}
    _applySignedOut();
  }

  @override
  void dispose() {
    _gateTimer?.cancel();
    _authSub?.cancel();
    _detachGates();
    super.dispose();
  }
}

final sessionProvider =
    StateNotifierProvider<SessionController, SessionState>(
  (ref) => SessionController(ref),
);
