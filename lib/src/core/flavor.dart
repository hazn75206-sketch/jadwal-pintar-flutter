/// Flavor aplikasi yang dibangun.
enum AppFlavor { user, admin }

extension AppFlavorX on AppFlavor {
  String get title => switch (this) {
        AppFlavor.user => 'Jadwal Pintar',
        AppFlavor.admin => 'Admin Jadwal Pintar',
      };
}
