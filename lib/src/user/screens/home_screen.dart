import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/sfx.dart';
import '../schedule_model.dart';
import '../schedule_provider.dart';
import '../session.dart';
import '../theme.dart';
import '../user_theme_provider.dart';
import '../update_download.dart';
import '../sheets/account_sheet.dart';
import '../sheets/data_sheet.dart';
import '../sheets/input_sheet.dart';

/// versionCode aplikasi ini (untuk cek update; naik tiap rilis).
const int kAppVersionCode = 3;

const List<String> _idMonths = <String>[
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

const List<String> _idDays = <String>[
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
];

/// Layar utama jadwal (faithful-port index.html): header, kartu harian,
/// FAB, menu, modal, overlay maintenance/update/blokir/kunci.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _menuOpen = false;
  bool _blockedDialogOpen = false;
  bool _gateShown = false;
  // Update opsional di-dismiss ("Nanti saja") — FAB tampil lagi.
  bool _updateDismissed = false;
  bool _scrolledToday = false;
  Timer? _minuteTimer;
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _dayKeys = {
    for (final day in kDays) day: GlobalKey(),
  };
  final _downloader = UpdateDownloader();

  @override
  void initState() {
    super.initState();
    _minuteTimer =
        Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday();
      _maybeShowGate();
    });
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    _scrollController.dispose();
    _downloader.dispose();
    super.dispose();
  }

  void _scrollToToday() {
    if (_scrolledToday) return;
    _scrolledToday = true;
    final today = _todayName();
    final key = today.isEmpty ? null : _dayKeys[today];
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final target = key?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          // ignore: use_build_context_synchronously
          target,
          duration: const Duration(milliseconds: 400),
          alignment: 0.3,
        );
      }
    });
  }

  String _todayName() {
    final weekday = DateTime.now().weekday;
    if (weekday == DateTime.sunday) return '';
    return kDays[weekday - 1];
  }

  String _todayLabel() {
    final today = _todayName();
    return today.isEmpty ? 'Selamat Berakhir Pekan' : 'Hari $today';
  }

  String _dateDetail() {
    final now = DateTime.now();
    final weekday = _idDays[now.weekday - 1];
    return '$weekday, ${now.day} ${_idMonths[now.month - 1]} ${now.year}';
  }

  void _maybeShowGate() {
    if (_gateShown) return;
    final session = ref.read(sessionProvider);
    if (session.status == SessionStatus.gate && !session.loginSkipped) {
      _gateShown = true;
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        final glass =
            ref.read(userThemeProvider).preset == ThemePreset.glass;
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: glass ? Colors.transparent : null,
          builder: (_) => const AccountSheet(),
        ).then((_) {
          final current = ref.read(sessionProvider);
          if (current.status == SessionStatus.gate &&
              !current.loginSkipped) {
            ref.read(sessionProvider.notifier).skipLogin();
          }
        });
      });
    }
  }

  void _listenSession() {
    ref.listen<SessionState>(sessionProvider, (previous, next) {
      if (next.status == SessionStatus.blocked && !_blockedDialogOpen) {
        _blockedDialogOpen = true;
        Sfx.play('error');
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PopScope(
            canPop: false,
            child: AlertDialog(
              icon: const FaIcon(FontAwesomeIcons.userLock),
              title: Text(next.blockedTitle.isEmpty
                  ? 'Akses akun dinonaktifkan'
                  : next.blockedTitle),
              content: Text(next.blockedMessage.isEmpty
                  ? 'Hubungi administrator jika memerlukan bantuan.'
                  : next.blockedMessage),
              actions: [
                FilledButton(
                  onPressed: () => Sfx.play('error'),
                  child: const Text('Mengerti'),
                ),
              ],
            ),
          ),
        ).then((_) => _blockedDialogOpen = false);
      }
      if (next.status == SessionStatus.loggedIn && _blockedDialogOpen) {
        _blockedDialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (next.status == SessionStatus.gate) {
        _gateShown = false;
        _maybeShowGate();
      }
    });
  }

  void _openSheet(Widget sheet) {
    Sfx.play('pop');
    final glass =
        ref.read(userThemeProvider).preset == ThemePreset.glass;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: glass ? Colors.transparent : null,
      builder: (_) => sheet,
    );
  }

  Future<void> _confirmDelete(String day, int index, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const FaIcon(FontAwesomeIcons.trashCan),
        title: const Text('Hapus Jadwal?'),
        content: Text('Hapus "$name" dari hari $day?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(scheduleProvider.notifier).deleteLesson(day, index);
    }
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const FaIcon(FontAwesomeIcons.trashCan),
        title: const Text('Kosongkan Semua?'),
        content: const Text(
          'Semua jadwal di semua hari akan dihapus. '
          'Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(scheduleProvider.notifier).clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    _listenSession();
    final session = ref.watch(sessionProvider);
    final schedule = ref.watch(scheduleProvider);
    final config = ref.watch(appConfigProvider);

    if (session.status == SessionStatus.boot) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (session.status == SessionStatus.locked) {
      // P4: popup TENGAH layar, tanpa tombol, tidak bisa dihilangkan.
      return const PopScope(
        canPop: false,
        child: Scaffold(body: _DeviceLockOverlay()),
      );
    }

    final today = _todayName();
    final maintenance = config.valueOrNull?.maintenance;
    final showMaintenance = maintenance?.enabled ?? false;
    final update = config.valueOrNull?.update;
    final showUpdate = update != null &&
        update.enabled &&
        update.versionCode > kAppVersionCode &&
        update.apkUrl.isNotEmpty;

    // P3: maintenance menutup SELURUH layar termasuk FAB (cermin native).
    if (showMaintenance) {
      return Scaffold(
        body: _MaintenanceOverlay(
          title: maintenance?.title ?? 'Aplikasi sedang diperbaiki',
          message: maintenance?.message ?? '',
        ),
      );
    }

    // D: reset status dismiss saat update hilang/muncul baru.
    if (!showUpdate && _updateDismissed) _updateDismissed = false;
    final forceUpdate = showUpdate && update.force;
    // D: update wajib = fullscreen tanpa FAB (cermin maintenance).
    if (forceUpdate) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          body: _UpdateOverlay(
            update: update,
            downloader: _downloader,
          ),
        ),
      );
    }

    // P5: preset Glass = efek kaca iPhone (blur + border + glow).
    final glass =
        ref.watch(userThemeProvider).preset == ThemePreset.glass;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Glow radial ala body native (yang di-blur kartu kaca).
            if (glass) ...const [
              Positioned(
                top: -130,
                left: -110,
                child: _GlowBlob(color: Color(0xFF007AFF)),
              ),
              Positioned(
                bottom: -150,
                right: -120,
                child: _GlowBlob(color: Color(0xFF5856D6)),
              ),
            ],
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                    child: _headerWrapped(session, glass)),
                if (_menuOpen)
                  SliverToBoxAdapter(
                    child: _MenuPanel(
                      onData: () => _openSheet(const DataSheet()),
                    ),
                  ),
                for (final day in kDays)
                  SliverToBoxAdapter(
                    child: _DayCard(
                      key: _dayKeys[day],
                      day: day,
                      isToday: day == today,
                      lessons: schedule.data.days[day] ?? const <String>[],
                      locked: schedule.locked,
                      glass: glass,
                      countdown: day == today
                          ? nextLessonToday(
                              schedule.data.days[day] ?? const <String>[],
                              schedule.startTime,
                              DateTime.now(),
                            )
                          : null,
                      onAdd: () => _openSheet(InputSheet(day: day)),
                      onEdit: (index) => _openSheet(
                        InputSheet(day: day, index: index),
                      ),
                      onDelete: (index) => _confirmDelete(
                        day,
                        index,
                        schedule.data.days[day]![index],
                      ),
                    ),
                  ),
                if (!schedule.locked && !schedule.data.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      child: OutlinedButton.icon(
                        onPressed: _confirmClearAll,
                        icon: const FaIcon(FontAwesomeIcons.trashCan,
                            size: 15),
                        label: const Text('Kosongkan Semua'),
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
              ],
            ),
            // D: update opsional tetap overlay, tapi menutup area FAB.
            if (showUpdate && !forceUpdate)
              Positioned.fill(
                child: _UpdateOverlay(
                  update: update,
                  downloader: _downloader,
                  onDismissed: () =>
                      setState(() => _updateDismissed = true),
                ),
              ),
          ],
        ),
      ),
      // D: FAB disembunyikan selama overlay update tampil.
      floatingActionButton: (showUpdate && !_updateDismissed)
          ? null
          : FloatingActionButton(
              onPressed: () {
                final day = today.isEmpty ? kDays.first : today;
                _openSheet(InputSheet(day: day));
              },
              child: const FaIcon(FontAwesomeIcons.plus),
            ),
    );
  }

  Widget _headerWrapped(SessionState session, bool glass) {
    final bar = _header(session);
    if (!glass) return bar;
    return _Glass(radius: 20, child: bar);
  }

  Widget _header(SessionState session) {
    final customPhoto = ref.watch(customPhotoProvider);
    final avatar = customPhoto.isNotEmpty ? customPhoto : session.photo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _openSheet(const AccountSheet()),
            child: CircleAvatar(
              radius: 22,
              backgroundImage:
                  avatar.isNotEmpty ? NetworkImage(avatar) : null,
              onBackgroundImageError:
                  avatar.isNotEmpty ? (_, _) {} : null,
              child: avatar.isEmpty
                  ? const FaIcon(FontAwesomeIcons.user, size: 18)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _todayLabel(),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  _dateDetail(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Sfx.play('click');
              setState(() => _menuOpen = !_menuOpen);
            },
            icon: FaIcon(
              _menuOpen
                  ? FontAwesomeIcons.eyeSlash
                  : FontAwesomeIcons.eye,
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel menu mata (data + kunci) di bawah header.
class _MenuPanel extends ConsumerWidget {
  const _MenuPanel({required this.onData});

  final VoidCallback onData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(scheduleProvider.select((s) => s.locked));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton.filledTonal(
            onPressed: onData,
            icon: const FaIcon(FontAwesomeIcons.folderOpen, size: 16),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () {
              ref.read(scheduleProvider.notifier).toggleLock();
            },
            icon: Icon(
              locked ? Icons.lock : Icons.lock_open,
              color: locked ? Colors.red : null,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bungkus kaca iPhone: blur latar + tint gelap + border hairline putih.
/// Cermin `.card` + `--glass-border` + `backdrop-filter` native.
class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.radius = 24});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x8C1C1C1E),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: const Color(0x1FFFFFFF),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Glow radial di latar (yang di-blur kartu kaca).
/// Cermin `background-image: radial-gradient(...)` body native.
class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 320,
        height: 320,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    super.key,
    required this.day,
    required this.isToday,
    required this.lessons,
    required this.locked,
    required this.glass,
    required this.countdown,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final String day;
  final bool isToday;
  final List<String> lessons;
  final bool locked;
  final bool glass;
  final ({String name, int minutesLeft})? countdown;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      day,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Hari Ini',
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              if (countdown != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.clock, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                  text: 'Pelajaran berikutnya: '),
                              TextSpan(
                                text: countdown!.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                              TextSpan(
                                text:
                                    ' (${countdownText(countdown!.minutesLeft)})',
                              ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 6),
              if (lessons.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Opacity(
                      opacity: 0.4,
                      child: Text(
                        'Tidak ada jadwal',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                )
              else
                for (var i = 0; i < lessons.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(lessons[i])),
                        if (!locked) ...[
                          IconButton(
                            onPressed: () => onEdit(i),
                            icon: const FaIcon(FontAwesomeIcons.pencil,
                                size: 15),
                          ),
                          IconButton(
                            onPressed: () => onDelete(i),
                            icon: FaIcon(
                              FontAwesomeIcons.trash,
                              size: 15,
                              color: scheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              if (!locked)
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const FaIcon(FontAwesomeIcons.circlePlus,
                      size: 15),
                  label: const Text('Tambah Pelajaran'),
                ),
            ],
          );
    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: content,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: glass
          ? _Glass(child: body)
          : Card(
              color: isToday ? scheme.primaryContainer : null,
              child: body,
            ),
    );
  }
}

class _MaintenanceOverlay extends StatelessWidget {
  const _MaintenanceOverlay({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    // Dipakai sebagai body Scaffold penuh (bukan di dalam Stack).
    return Container(
      color: const Color(0xFF080C18),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.handyman_outlined,
              size: 38,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF7F9FF),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF97AAC8),
              fontSize: 14,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateOverlay extends StatefulWidget {
  const _UpdateOverlay({
    required this.update,
    required this.downloader,
    this.onDismissed,
  });

  final UpdateConfig update;
  final UpdateDownloader downloader;

  /// Dipanggil saat update opsional di-dismiss ("Nanti saja").
  final VoidCallback? onDismissed;

  @override
  State<_UpdateOverlay> createState() => _UpdateOverlayState();
}

class _UpdateOverlayState extends State<_UpdateOverlay> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final update = widget.update;
    final title = update.title;
    final message = update.message;
    final apkUrl = update.apkUrl;
    final versionName = update.versionName;
    final force = update.force;
    // Dipakai fullscreen (force) maupun di Stack (opsional).
    return Container(
        color: const Color(0xFF060B16),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.download_outlined,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF7F9FF),
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF97AAC8),
                fontSize: 14,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 22),
            ListenableBuilder(
              listenable: widget.downloader,
              builder: (context, _) {
                final downloading = widget.downloader.status ==
                    UpdateDownloadStatus.downloading;
                final error = widget.downloader.status ==
                    UpdateDownloadStatus.error;
                return Column(
                  children: [
                    FilledButton(
                      onPressed: downloading
                          ? null
                          : () async {
                              final err = await widget.downloader
                                  .downloadAndOpen(apkUrl, versionName);
                              if (err != null && context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(content: Text(err)),
                                );
                              }
                            },
                      child: Text(
                        downloading
                            ? 'Sedang mengunduh...'
                            : (error ? 'Coba unduh lagi' : 'Unduh & Pasang'),
                      ),
                    ),
                    if (!force)
                      TextButton(
                        onPressed: () {
                          setState(() => _dismissed = true);
                          widget.onDismissed?.call();
                        },
                        child: const Text(
                          'Nanti saja',
                          style:
                              TextStyle(color: Color(0xFF97AAC8)),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
    );
  }
}

/// Popup blokir perangkat: TENGAH layar, TANPA tombol, tidak bisa
/// dihilangkan (aturan user). Back-button dikunci via PopScope pemanggil.
class _DeviceLockOverlay extends StatelessWidget {
  const _DeviceLockOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF04060C),
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
            decoration: BoxDecoration(
              color: const Color(0xFF10141F),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0x1FFFFFFF),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context)
                        .colorScheme
                        .error
                        .withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.block_outlined,
                    size: 30,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'PERANGKAT DIBLOKIR',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Perangkat ini diblokir',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Perangkat ini tidak diizinkan mengakses Jadwal Pintar. '
                  'Hubungi administrator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFF97AAC8), fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
