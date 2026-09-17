import 'dart:async';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'schedule_model.dart';

/// Pengingat jadwal exact (cermin AlarmScheduler + AlarmReceiver native):
/// tiap hari berisi jadwal → 1x H-5 menit + 1x tepat jam masuk, berulang
/// mingguan, tahan reboot via `rescheduleOnReboot`.
class AlarmService {
  AlarmService._();

  static const String channelId = 'jadwal_channel';
  static const String channelName = 'Pengingat Jadwal';
  static const String channelDesc = 'Pengingat jam masuk pelajaran';

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notifications.initialize(settings);
    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDesc,
      importance: Importance.high,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Pasang ulang seluruh alarm dari jadwal + jam masuk.
  static Future<void> reschedule(
    ScheduleData schedule,
    String startTime,
  ) async {
    await init();
    await cancelAll();
    final entries = buildAlarmEntries(schedule, startTime);
    for (final entry in entries) {
      final next = _nextOccurrence(entry.dow, entry.hour, entry.minute);
      if (next == null) continue;
      try {
        await AndroidAlarmManager.oneShotAt(
          next,
          entry.alarmId,
          _alarmFired,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
          params: <String, String>{
            'title': entry.title,
            'text': entry.text,
            'dow': '${entry.dow}',
            'hour': '${entry.hour}',
            'minute': '${entry.minute}',
          },
        );
      } catch (_) {}
    }
  }

  static Future<void> cancelAll() async {
    try {
      final entries = <int>[];
      for (var dow = 1; dow <= 7; dow++) {
        entries.add(dow * 10);
        entries.add(dow * 10 + 1);
      }
      for (final id in entries) {
        try {
          await AndroidAlarmManager.cancel(id);
        } catch (_) {}
      }
    } catch (_) {}
    try {
      await _notifications.cancelAll();
    } catch (_) {}
  }

  /// Kemunculan berikutnya dari (dow Calendar, jam:menit), margin 60 dtk
  /// (cermin margin native agar alarm baru berbunyi tak terpilih lagi).
  static DateTime? _nextOccurrence(int dow, int hour, int minute) {
    final weekday = dateTimeWeekday(dow);
    final now = DateTime.now().add(const Duration(seconds: 60));
    var day = DateTime(now.year, now.month, now.day, hour, minute);
    for (var i = 0; i <= 7; i++) {
      if (day.weekday == weekday && !day.isBefore(now)) return day;
      day = day.add(const Duration(days: 1));
    }
    return day;
  }
}

/// Callback background saat alarm berbunyi: tampilkan notifikasi +
/// jadwalkan kemunculan minggu depan (rantai cermin scheduleNext native).
@pragma('vm:entry-point')
Future<void> _alarmFired(int id, Map<String, dynamic>? params) async {
  final plugin = FlutterLocalNotificationsPlugin();
  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await plugin.initialize(settings);
  final title = '${params?['title'] ?? 'Jadwal Pintar'}';
  final text = '${params?['text'] ?? 'Saatnya pelajaran dimulai'}';
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      AlarmService.channelId,
      AlarmService.channelName,
      channelDescription: AlarmService.channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    ),
  );
  await plugin.show(id, title, text, details);
  // Rantai mingguan.
  try {
    final dow = int.tryParse('${params?['dow']}') ?? -1;
    final hour = int.tryParse('${params?['hour']}') ?? -1;
    final minute = int.tryParse('${params?['minute']}') ?? 0;
    if (dow >= 1 && dow <= 7 && hour >= 0 && hour <= 23) {
      final weekday = dateTimeWeekday(dow);
      var day = DateTime.now();
      day = DateTime(day.year, day.month, day.day, hour, minute);
      while (day.weekday != weekday || !day.isAfter(DateTime.now())) {
        day = day.add(const Duration(days: 1));
      }
      final nextWeek = day.add(const Duration(days: 7));
      await AndroidAlarmManager.oneShotAt(
        nextWeek,
        id,
        _alarmFired,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        params: params,
      );
    }
  } catch (_) {}
}
