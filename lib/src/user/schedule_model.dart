import 'dart:convert';

/// Hari aktif: Senin–Sabtu (cermin `days` di script.js native).
const List<String> kDays = <String>[
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
];

/// Map hari -> Calendar.DAY_OF_WEEK (Senin=2 … Sabtu=7).
int calendarDow(String day) => kDays.indexOf(day) + 2;

/// Map Calendar.DAY_OF_WEEK -> DateTime.weekday (Mon=1..Sun=7).
int dateTimeWeekday(int calendarDowValue) =>
    calendarDowValue == 1 ? 7 : calendarDowValue - 1;

/// Data jadwal: map hari -> daftar nama pelajaran (string).
/// Format JSON identik dengan `jadwal_v2` native agar cloud & file
/// impor/ekspor saling terbaca lintas versi aplikasi.
class ScheduleData {
  ScheduleData([Map<String, List<String>>? days])
      : days = {
          for (final day in kDays)
            day: List<String>.from(days?[day] ?? const <String>[]),
        };

  final Map<String, List<String>> days;

  factory ScheduleData.fromJsonString(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = <String, List<String>>{};
        decoded.forEach((key, value) {
          final day = '$key';
          if (value is List) {
            map[day] = value.map((e) => '$e').toList();
          }
        });
        return ScheduleData(map);
      }
    } catch (_) {}
    return ScheduleData();
  }

  String toJsonString() => jsonEncode(days);

  bool get isEmpty => days.values.every((list) => list.isEmpty);

  ScheduleData copy() => ScheduleData(
        {for (final e in days.entries) e.key: List<String>.from(e.value)},
      );
}

/// Satu entri alarm pengingat (cermin payload `updateAlarms` native).
class AlarmEntry {
  const AlarmEntry({
    required this.dow,
    required this.hour,
    required this.minute,
    required this.title,
    required this.text,
    required this.kind,
  });

  /// Calendar.DAY_OF_WEEK.
  final int dow;
  final int hour;
  final int minute;
  final String title;
  final String text;

  /// 0 = H-5 menit, 1 = tepat jam masuk.
  final int kind;

  /// ID stabil per (hari, jenis).
  int get alarmId => dow * 10 + kind;
}

/// Susun daftar alarm dari jadwal + jam masuk (cermin `updateAlarms`):
/// tiap hari berisi jadwal → 1x H-5 menit + 1x tepat jam masuk.
List<AlarmEntry> buildAlarmEntries(
  ScheduleData schedule,
  String startTime,
) {
  final parts = startTime.split(':');
  final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 7;
  final minute =
      int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
  var preHour = hour;
  var preMinute = minute - 5;
  if (preMinute < 0) {
    preMinute += 60;
    preHour = (preHour + 23) % 24;
  }
  final entries = <AlarmEntry>[];
  for (final day in kDays) {
    final lessons = schedule.days[day] ?? const <String>[];
    if (lessons.isEmpty) continue;
    final dow = calendarDow(day);
    final first = lessons.first;
    entries.add(AlarmEntry(
      dow: dow,
      hour: preHour,
      minute: preMinute,
      title: 'Jadwal Pintar',
      text: '5 menit lagi masuk. Pelajaran pertama: $first',
      kind: 0,
    ));
    entries.add(AlarmEntry(
      dow: dow,
      hour: hour,
      minute: minute,
      title: 'Jadwal Pintar',
      text: 'Pelajaran dimulai: $first',
      kind: 1,
    ));
  }
  return entries;
}

/// Hitung pelajaran berikutnya hari ini (cermin `createCountdownElement`):
/// slot 45 menit dari jam masuk. Mengembalikan (nama, menit tersisa).
({String name, int minutesLeft})? nextLessonToday(
  List<String> lessons,
  String startTime,
  DateTime now,
) {
  if (lessons.isEmpty) return null;
  final parts = startTime.split(':');
  final baseHour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 7;
  final baseMin = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
  final currentMinutes = now.hour * 60 + now.minute;
  for (var i = 0; i < lessons.length; i++) {
    final lessonMinutes = baseHour * 60 + baseMin + i * 45;
    if (lessonMinutes > currentMinutes) {
      return (
        name: lessons[i],
        minutesLeft: lessonMinutes - currentMinutes,
      );
    }
  }
  return null;
}

/// Teks countdown Indonesia: "2 jam 5 menit" / "25 menit".
String countdownText(int minutesLeft) {
  final hours = minutesLeft ~/ 60;
  final mins = minutesLeft % 60;
  if (hours > 0) return '$hours jam $mins menit';
  return '$mins menit';
}
