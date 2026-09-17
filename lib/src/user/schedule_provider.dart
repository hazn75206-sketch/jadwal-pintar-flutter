import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database_service.dart';
import '../core/prefs.dart';
import '../core/providers.dart';
import '../core/sfx.dart';
import 'alarm_service.dart';
import 'schedule_model.dart';

/// Status badge sinkron (cermin `setSyncBadge` native).
enum SyncBadge { idle, syncing, ok, error }

/// State jadwal + preferensi tampilan terkait.
class ScheduleState {
  const ScheduleState({
    required this.data,
    required this.locked,
    required this.startTime,
    required this.badge,
    required this.lastSync,
  });

  final ScheduleData data;
  final bool locked;
  final String startTime;
  final SyncBadge badge;
  final String lastSync;

  ScheduleState copyWith({
    ScheduleData? data,
    bool? locked,
    String? startTime,
    SyncBadge? badge,
    String? lastSync,
  }) {
    return ScheduleState(
      data: data ?? this.data,
      locked: locked ?? this.locked,
      startTime: startTime ?? this.startTime,
      badge: badge ?? this.badge,
      lastSync: lastSync ?? this.lastSync,
    );
  }
}

/// Pengelola jadwal lokal + sinkron cloud + alarm (cermin script.js).
class ScheduleController extends StateNotifier<ScheduleState> {
  ScheduleController(this._ref)
      : super(ScheduleState(
          data: ScheduleData(),
          locked: false,
          startTime: '07:00',
          badge: SyncBadge.idle,
          lastSync: '',
        )) {
    _loadLocal();
  }

  final Ref _ref;
  Timer? _syncTimer;

  DatabaseService get _db => _ref.read(databaseProvider);

  String? get _uid =>
      _ref.read(authServiceProvider).current?.uid;

  Future<void> _loadLocal() async {
    try {
      final prefs = await _ref.read(prefsProvider.future);
      final raw = prefs.getString(PrefKeys.schedule) ?? '{}';
      final lockedRaw = prefs.getString(PrefKeys.locked) ?? 'false';
      state = state.copyWith(
        data: ScheduleData.fromJsonString(raw),
        locked: lockedRaw == 'true',
        startTime: prefs.getString(PrefKeys.startTime) ?? '07:00',
        lastSync: prefs.getString(PrefKeys.lastSync) ?? '',
      );
      await rescheduleAlarms();
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await _ref.read(prefsProvider.future);
      await prefs.setString(
          PrefKeys.schedule, state.data.toJsonString());
      await prefs.setString(
          PrefKeys.locked, state.locked.toString());
      await prefs.setString(PrefKeys.startTime, state.startTime);
      await prefs.setString(PrefKeys.lastSync, state.lastSync);
    } catch (_) {}
  }

  // ---------- CRUD (cermin saveSubject/openDelete/openClearAll) ----------

  Future<void> addLessons(String day, List<String> values) async {
    final clean =
        values.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (clean.isEmpty) return;
    final next = state.data.copy();
    next.days[day] = [...next.days[day] ?? const <String>[], ...clean];
    state = state.copyWith(data: next);
    await _afterEdit(sound: 'success');
  }

  Future<void> editLesson(String day, int index, String value) async {
    final clean = value.trim();
    if (clean.isEmpty) return;
    final next = state.data.copy();
    final list = next.days[day] ?? <String>[];
    if (index < 0 || index >= list.length) return;
    list[index] = clean;
    state = state.copyWith(data: next);
    await _afterEdit(sound: 'success');
  }

  Future<void> deleteLesson(String day, int index) async {
    final next = state.data.copy();
    final list = next.days[day] ?? <String>[];
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    state = state.copyWith(data: next);
    await _afterEdit(sound: 'error');
  }

  Future<void> clearAll() async {
    state = state.copyWith(data: ScheduleData());
    await _afterEdit(sound: 'error');
  }

  Future<void> toggleLock() async {
    state = state.copyWith(locked: !state.locked);
    await _persist();
  }

  Future<void> setStartTime(String value) async {
    state = state.copyWith(startTime: value);
    try {
      final prefs = await _ref.read(prefsProvider.future);
      await prefs.setString(PrefKeys.startTime, value);
    } catch (_) {}
    await rescheduleAlarms();
  }

  Future<void> _afterEdit({required String sound}) async {
    await _persist();
    await rescheduleAlarms();
    await Sfx.play(sound);
    autoSync();
  }

  // ---------- Impor / ekspor (cermin importData/exportData) ----------

  /// Mengembalikan null bila sukses, atau pesan error Indonesia.
  Future<String?> importJson(String raw) async {
    try {
      final parsed = ScheduleData.fromJsonString(raw);
      state = state.copyWith(data: parsed);
      await _afterEdit(sound: 'success');
      return null;
    } catch (_) {
      await Sfx.play('error');
      return 'File tidak valid!';
    }
  }

  String exportJson() => state.data.toJsonString();

  // ---------- Sinkron cloud (cermin autoSync/doSyncNow/doRestore) ----------

  void autoSync() {
    _syncTimer?.cancel();
    if (_uid == null) return;
    state = state.copyWith(badge: SyncBadge.syncing);
    _syncTimer = Timer(const Duration(milliseconds: 2500), () {
      _syncTimer = null;
      syncNow();
    });
  }

  Future<void> syncNow() async {
    final uid = _uid;
    if (uid == null) return;
    _syncTimer?.cancel();
    _syncTimer = null;
    state = state.copyWith(badge: SyncBadge.syncing);
    try {
      await _db.saveSchedule(uid, state.data.toJsonString());
      await _recordSync();
    } catch (_) {
      state = state.copyWith(badge: SyncBadge.error);
    }
  }

  /// Muat dari cloud: ada isi → pakai cloud; kosong → unggah lokal.
  /// (cermin onCloudData/onCloudEmpty).
  Future<void> restoreFromCloud() async {
    final uid = _uid;
    if (uid == null) return;
    state = state.copyWith(badge: SyncBadge.syncing);
    try {
      final remote = await _db.loadSchedule(uid);
      if (remote == null || remote.isEmpty) {
        await syncNow();
        return;
      }
      state = state.copyWith(
        data: ScheduleData.fromJsonString(remote),
      );
      await _persist();
      await rescheduleAlarms();
      await _recordSync();
    } catch (_) {
      state = state.copyWith(badge: SyncBadge.error);
    }
  }

  Future<void> _recordSync() async {
    final stamp = DateTime.now().toIso8601String();
    state = state.copyWith(badge: SyncBadge.ok, lastSync: stamp);
    try {
      final prefs = await _ref.read(prefsProvider.future);
      await prefs.setString(PrefKeys.lastSync, stamp);
    } catch (_) {}
  }

  // ---------- Alarm ----------

  Future<void> rescheduleAlarms() async {
    try {
      await AlarmService.reschedule(state.data, state.startTime);
    } catch (_) {}
  }

  Future<void> cancelAlarms() async {
    try {
      await AlarmService.cancelAll();
    } catch (_) {}
  }

  // ---------- Wipe saat diblokir (cermin onAccountWiped; lokal saja) ----------

  Future<void> wipeLocal() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    try {
      final prefs = await _ref.read(prefsProvider.future);
      await prefs.remove(PrefKeys.schedule);
      await prefs.remove(PrefKeys.locked);
      await prefs.remove(PrefKeys.lastSync);
      await prefs.remove(PrefKeys.customPhoto);
      await prefs.remove(PrefKeys.loginSkipped);
    } catch (_) {}
    state = ScheduleState(
      data: ScheduleData(),
      locked: false,
      startTime: state.startTime,
      badge: SyncBadge.idle,
      lastSync: '',
    );
    await cancelAlarms();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

final scheduleProvider =
    StateNotifierProvider<ScheduleController, ScheduleState>(
  (ref) => ScheduleController(ref),
);
