/// Nama node/field Realtime Database — cerminan 1:1 skema native/REST.
/// Satu-satunya sumber kebenaran agar user, admin, dan rules konsisten.
abstract final class Rtdb {
  static const String admins = 'admins';
  static const String appConfig = 'appConfig';
  static const String maintenance = 'maintenance';
  static const String update = 'update';
  static const String accessBlocked = 'accessBlocked';
  static const String deviceProtection = 'deviceProtection';
  static const String userProfiles = 'userProfiles';
  static const String userAccess = 'userAccess';
  static const String deviceBans = 'deviceBans';
  static const String adminAuditLogs = 'adminAuditLogs';
  static const String users = 'users';
  static const String jadwal = 'jadwal';
  static const String profilePhoto = 'profilePhoto';
}

/// Normalisasi nilai mentah snapshot menjadi Map<String, dynamic>.
Map<String, dynamic> rtdbMap(dynamic value) {
  if (value is Map) {
    return value.map((key, val) => MapEntry('$key', val));
  }
  return <String, dynamic>{};
}
