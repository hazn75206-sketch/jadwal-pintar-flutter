import 'package:firebase_database/firebase_database.dart';

import 'models.dart';
import 'rtdb_schema.dart';

/// Akses Realtime Database via SDK: stream realtime + tulis tipikal.
/// Menggantikan seluruh polling REST era native.
class DatabaseService {
  DatabaseService({FirebaseDatabase? database})
      : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference get _root => _db.ref();

  // ---------- Stream ----------

  Stream<AppConfig> appConfigStream() => _root
      .child(Rtdb.appConfig)
      .onValue
      .map((event) => AppConfig.fromMap(rtdbMap(event.snapshot.value)));

  Stream<UserAccess?> userAccessStream(String uid) => _root
      .child('${Rtdb.userAccess}/$uid')
      .onValue
      .map((event) => event.snapshot.exists
          ? UserAccess.fromMap(rtdbMap(event.snapshot.value))
          : null);

  Stream<DeviceBan?> deviceBanStream(String hash) => _root
      .child('${Rtdb.deviceBans}/$hash')
      .onValue
      .map((event) => event.snapshot.exists
          ? DeviceBan.fromMap(rtdbMap(event.snapshot.value))
          : null);

  Stream<Map<String, UserProfile>> profilesStream() => _root
      .child(Rtdb.userProfiles)
      .onValue
      .map((event) {
    final out = <String, UserProfile>{};
    final raw = event.snapshot.value;
    if (raw is Map) {
      raw.forEach((key, value) {
        out['$key'] = UserProfile.fromMap('$key', rtdbMap(value));
      });
    }
    return out;
  });

  Stream<Map<String, UserAccess>> accessMapStream() => _root
      .child(Rtdb.userAccess)
      .onValue
      .map((event) {
    final out = <String, UserAccess>{};
    final raw = event.snapshot.value;
    if (raw is Map) {
      raw.forEach((key, value) {
        out['$key'] = UserAccess.fromMap(rtdbMap(value));
      });
    }
    return out;
  });

  Stream<Map<String, DeviceBan>> bansStream() =>
      _root.child(Rtdb.deviceBans).onValue.map((event) {
        final out = <String, DeviceBan>{};
        final raw = event.snapshot.value;
        if (raw is Map) {
          raw.forEach((key, value) {
            final ban = DeviceBan.fromMap(rtdbMap(value));
            if (ban.banned) out['$key'] = ban;
          });
        }
        return out;
      });

  /// true bila socket database tersambung (sinyal online paling akurat).
  Stream<bool> connectedStream() => _db
      .ref('.info/connected')
      .onValue
      .map((event) => event.snapshot.value as bool? ?? false);

  // ---------- Baca sekali ----------

  /// true bila [uid] terdaftar sebagai admin aktif.
  Future<bool> isAdmin(String uid) async {
    final snapshot = await _root.child('${Rtdb.admins}/$uid').get();
    if (!snapshot.exists) return false;
    final value = snapshot.value;
    if (value is bool) return value;
    if (value is Map) {
      return (value['enabled'] as bool?) ?? false;
    }
    return false;
  }

  Future<String?> loadSchedule(String uid) async {
    final snapshot =
        await _root.child('${Rtdb.users}/$uid/${Rtdb.jadwal}').get();
    if (!snapshot.exists) return null;
    final value = snapshot.value;
    if (value is String) return value.isEmpty ? null : value;
    return null;
  }

  Future<String> loadProfilePhoto(String uid) async {
    final snapshot =
        await _root.child('${Rtdb.users}/$uid/${Rtdb.profilePhoto}').get();
    final value = snapshot.value;
    return value is String ? value : '';
  }

  /// Baca sekali status ban perangkat (untuk tolak-login di HP banned).
  Future<DeviceBan?> loadDeviceBan(String hash) async {
    final snapshot =
        await _root.child('${Rtdb.deviceBans}/$hash').get();
    if (!snapshot.exists) return null;
    return DeviceBan.fromMap(rtdbMap(snapshot.value));
  }

  /// Daftar perangkat milik 1 akun (multi-device). Butuh rules v3.
  Future<Map<String, UserDevice>> loadUserDevices(String uid) async {
    final snapshot =
        await _root.child('${Rtdb.userDevices}/$uid').get();
    final out = <String, UserDevice>{};
    final raw = snapshot.value;
    if (raw is Map) {
      raw.forEach((key, value) {
        out['$key'] = UserDevice.fromMap('$key', rtdbMap(value));
      });
    }
    return out;
  }

  /// Catat/perbarui 1 perangkat milik akun (merge; perangkat lain utuh).
  Future<void> writeDevice(
    String uid,
    String hash,
    Map<String, Object?> map,
  ) =>
      _root.child('${Rtdb.userDevices}/$uid/$hash').update(map);

  /// Tandai perangkat online + otomatis offline saat koneksi putus.
  Future<void> armDeviceOfflineMarker(String uid, String hash) => _root
      .child('${Rtdb.userDevices}/$uid/$hash')
      .onDisconnect()
      .update(<String, Object?>{
        'online': false,
        'lastSeenAt': ServerValue.timestamp,
      });

  // ---------- Tulis ----------

  Future<void> saveSchedule(String uid, String json) =>
      _root.child('${Rtdb.users}/$uid/${Rtdb.jadwal}').set(json);

  Future<void> saveProfilePhoto(String uid, String dataUrl) =>
      _root.child('${Rtdb.users}/$uid/${Rtdb.profilePhoto}').set(dataUrl);

  Future<void> writeProfile(String uid, Map<String, Object?> map) =>
      _root.child('${Rtdb.userProfiles}/$uid').set(map);

  Future<void> updatePresence(String uid, bool online) =>
      _root.child('${Rtdb.userProfiles}/$uid').update(<String, Object?>{
        'online': online,
        if (!online) 'lastSeenAt': ServerValue.timestamp,
      });

  Future<void> heartbeat(String uid) => _root
      .child('${Rtdb.userProfiles}/$uid/lastSeenAt')
      .set(ServerValue.timestamp);

  /// Tandai offline otomatis saat koneksi putus (presence akurat).
  Future<void> armOfflineMarker(String uid) => _root
      .child('${Rtdb.userProfiles}/$uid')
      .onDisconnect()
      .update(<String, Object?>{
        'online': false,
        'lastSeenAt': ServerValue.timestamp,
      });

  Future<void> setUserAccess(
    String uid, {
    required bool enabled,
    required String by,
  }) =>
      _root.child('${Rtdb.userAccess}/$uid').set(<String, Object?>{
        'enabled': enabled,
        'updatedAt': ServerValue.timestamp,
        'updatedBy': by,
      });

  Future<void> setDeviceBan(String hash, Map<String, Object?> map) =>
      _root.child('${Rtdb.deviceBans}/$hash').set(map);

  Future<void> removeDeviceBan(String hash) =>
      _root.child('${Rtdb.deviceBans}/$hash').remove();

  /// Hapus SELURUH riwayat 1 akun: jadwal+foto (users), profil,
  /// dan status akses. Butuh rules v2 (admin boleh tulis).
  /// Blokir perangkat TIDAK ikut (kelola di layar Blokir).
  Future<void> deleteUserData(String uid) => Future.wait(<Future<void>>[
        _root.child('${Rtdb.users}/$uid').remove(),
        _root.child('${Rtdb.userProfiles}/$uid').remove(),
        _root.child('${Rtdb.userAccess}/$uid').remove(),
      ]);

  Future<void> saveAppConfig(Map<String, Object?> map) =>
      _root.child(Rtdb.appConfig).set(map);

  Future<void> writeAudit({
    required String adminUid,
    required String adminEmail,
    required String action,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _root.child('${Rtdb.adminAuditLogs}/${now}_$adminUid').set(
      <String, Object?>{
        'adminUid': adminUid,
        'adminEmail': adminEmail,
        'action': action,
        'timestamp': now,
      },
    );
  }
}
