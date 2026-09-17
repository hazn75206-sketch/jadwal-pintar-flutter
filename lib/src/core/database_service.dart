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
