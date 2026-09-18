import 'rtdb_schema.dart';

/// Model-model mirror skema RTDB. Semua field defensif (default aman)
// tangani data lama / null dari database.

class MaintenanceConfig {
  const MaintenanceConfig({
    this.enabled = false,
    this.title = 'Aplikasi sedang diperbaiki',
    this.message = 'Silakan coba kembali beberapa saat lagi.',
  });

  final bool enabled;
  final String title;
  final String message;

  factory MaintenanceConfig.fromMap(Map<String, dynamic> map) {
    return MaintenanceConfig(
      enabled: map['enabled'] == true,
      title: '${map['title'] ?? 'Aplikasi sedang diperbaiki'}',
      message: '${map['message'] ?? 'Silakan coba kembali beberapa saat lagi.'}',
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'enabled': enabled,
        'title': title,
        'message': message,
      };
}

class UpdateConfig {
  const UpdateConfig({
    this.enabled = false,
    this.force = false,
    this.versionCode = 1,
    this.versionName = '1.0',
    this.apkUrl = '',
    this.storageBucket = 'jadwal-pintar.firebasestorage.app',
    this.title = 'Update tersedia',
    this.message = 'Silakan perbarui aplikasi ke versi terbaru.',
  });

  final bool enabled;
  final bool force;
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String storageBucket;
  final String title;
  final String message;

  factory UpdateConfig.fromMap(Map<String, dynamic> map) {
    return UpdateConfig(
      enabled: map['enabled'] == true,
      force: map['force'] == true,
      versionCode: (map['versionCode'] as num?)?.toInt() ?? 1,
      versionName: '${map['versionName'] ?? '1.0'}',
      apkUrl: '${map['apkUrl'] ?? ''}',
      storageBucket:
          '${map['storageBucket'] ?? 'jadwal-pintar.firebasestorage.app'}',
      title: '${map['title'] ?? 'Update tersedia'}',
      message:
          '${map['message'] ?? 'Silakan perbarui aplikasi ke versi terbaru.'}',
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'enabled': enabled,
        'force': force,
        'versionCode': versionCode,
        'versionName': versionName,
        'apkUrl': apkUrl,
        'storageBucket': storageBucket,
        'title': title,
        'message': message,
      };
}

class PopupConfig {
  const PopupConfig({
    this.title = 'Akses akun dinonaktifkan',
    this.message =
        'Akun Anda sementara tidak dapat menggunakan fitur cloud. Hubungi administrator jika memerlukan bantuan.',
  });

  final String title;
  final String message;

  factory PopupConfig.fromMap(Map<String, dynamic> map) {
    return PopupConfig(
      title: '${map['title'] ?? 'Akses akun dinonaktifkan'}',
      message:
          '${map['message'] ?? 'Akun Anda sementara tidak dapat menggunakan fitur cloud. Hubungi administrator jika memerlukan bantuan.'}',
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'title': title,
        'message': message,
      };
}

class DeviceProtectionConfig {
  const DeviceProtectionConfig({
    this.enabled = false,
    this.updatedAt = 0,
    this.updatedBy = '',
  });

  final bool enabled;
  final int updatedAt;
  final String updatedBy;

  factory DeviceProtectionConfig.fromMap(Map<String, dynamic> map) {
    return DeviceProtectionConfig(
      enabled: map['enabled'] == true,
      updatedAt: (map['updatedAt'] as num?)?.toInt() ?? 0,
      updatedBy: '${map['updatedBy'] ?? ''}',
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'enabled': enabled,
        'updatedAt': updatedAt,
        'updatedBy': updatedBy,
      };
}

class AppConfig {
  const AppConfig({
    this.maintenance = const MaintenanceConfig(),
    this.update = const UpdateConfig(),
    this.popup = const PopupConfig(),
    this.protection = const DeviceProtectionConfig(),
  });

  final MaintenanceConfig maintenance;
  final UpdateConfig update;
  final PopupConfig popup;
  final DeviceProtectionConfig protection;

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      maintenance:
          MaintenanceConfig.fromMap(rtdbMap(map[Rtdb.maintenance])),
      update: UpdateConfig.fromMap(rtdbMap(map[Rtdb.update])),
      popup: PopupConfig.fromMap(rtdbMap(map[Rtdb.accessBlocked])),
      protection: DeviceProtectionConfig.fromMap(
          rtdbMap(map[Rtdb.deviceProtection])),
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.uid,
    this.name = 'Pengguna tanpa nama',
    this.email = 'Email tidak tersedia',
    this.photo = '',
    this.appVersion = '-',
    this.deviceModel = '-',
    this.osVersion = 'Android',
    this.createdAt = 0,
    this.lastLoginAt = 0,
    this.lastSeenAt = 0,
    this.online = false,
    this.deviceIdHash = '',
    this.deviceIdMissing = false,
  });

  final String uid;
  final String name;
  final String email;
  final String photo;
  final String appVersion;
  final String deviceModel;
  final String osVersion;
  final int createdAt;
  final int lastLoginAt;
  final int lastSeenAt;
  final bool online;
  final String deviceIdHash;
  final bool deviceIdMissing;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      name: _str(map['name'], 'Pengguna tanpa nama'),
      email: _str(map['email'], 'Email tidak tersedia'),
      photo: _str(map['photo'], ''),
      appVersion: _str(map['appVersion'], '-'),
      deviceModel: _str(map['deviceModel'], '-'),
      osVersion: _str(map['osVersion'], 'Android'),
      createdAt: _int(map['createdAt']),
      lastLoginAt: _int(map['lastLoginAt']),
      lastSeenAt: _int(map['lastSeenAt']),
      online: map['online'] == true,
      deviceIdHash: _str(map['deviceIdHash'], ''),
      deviceIdMissing: map['deviceIdMissing'] == true,
    );
  }

  bool isOnlineNow() =>
      lastSeenAt > 0 &&
      DateTime.now().millisecondsSinceEpoch - lastSeenAt < 120000;

  String shortDeviceId() =>
      deviceIdHash.length >= 12 ? '${deviceIdHash.substring(0, 12)}…' : '-';

  String searchableText() =>
      '$name $email $appVersion $deviceModel $osVersion $deviceIdHash';
}

/// Satu perangkat milik akun (multi-device): 1 akun bisa punya
/// banyak HP (mis. RMX2189 + S688LN), masing-masing bisa diblokir
/// terpisah lewat hash-nya. Node: userDevices/{uid}/{hash}.
class UserDevice {
  const UserDevice({
    required this.hash,
    this.deviceModel = '-',
    this.appVersion = '-',
    this.lastSeenAt = 0,
    this.online = false,
  });

  final String hash;
  final String deviceModel;
  final String appVersion;
  final int lastSeenAt;
  final bool online;

  factory UserDevice.fromMap(String hash, Map<String, dynamic> map) {
    return UserDevice(
      hash: hash,
      deviceModel: _str(map['deviceModel'], '-'),
      appVersion: _str(map['appVersion'], '-'),
      lastSeenAt: _int(map['lastSeenAt']),
      online: map['online'] == true,
    );
  }

  bool isOnlineNow() =>
      lastSeenAt > 0 &&
      DateTime.now().millisecondsSinceEpoch - lastSeenAt < 120000;

  String shortHash() =>
      hash.length >= 12 ? '${hash.substring(0, 12)}…' : '-';
}

class UserAccess {
  const UserAccess({
    this.enabled = true,
    this.updatedAt = 0,
    this.updatedBy = '',
  });

  final bool enabled;
  final int updatedAt;
  final String updatedBy;

  factory UserAccess.fromMap(Map<String, dynamic> map) {
    return UserAccess(
      enabled: map['enabled'] is bool ? map['enabled'] as bool : true,
      updatedAt: _int(map['updatedAt']),
      updatedBy: _str(map['updatedBy'], ''),
    );
  }
}

class DeviceBan {
  const DeviceBan({
    this.banned = false,
    this.uid = '',
    this.name = '',
    this.email = '',
    this.deviceModel = '',
    this.createdAt = 0,
    this.createdBy = '',
  });

  final bool banned;
  final String uid;
  final String name;
  final String email;
  final String deviceModel;
  final int createdAt;
  final String createdBy;

  factory DeviceBan.fromMap(Map<String, dynamic> map) {
    return DeviceBan(
      banned: map['banned'] == true,
      uid: _str(map['uid'], ''),
      name: _str(map['name'], ''),
      email: _str(map['email'], ''),
      deviceModel: _str(map['deviceModel'], ''),
      createdAt: _int(map['createdAt']),
      createdBy: _str(map['createdBy'], ''),
    );
  }
}

String _str(dynamic value, String fallback) {
  if (value == null) return fallback;
  final text = '$value';
  return text.isEmpty ? fallback : text;
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return 0;
}
