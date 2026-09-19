import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/sfx.dart';
import '../schedule_model.dart';
import '../schedule_provider.dart';
import '../session.dart';
import '../sheets/account_sheet.dart';
import '../sheets/data_sheet.dart';
import '../sheets/input_sheet.dart';
import '../sheets/liquid_glass.dart';
import '../theme.dart';
import '../user_theme_provider.dart';
import '../update_download.dart';

/// versionCode aplikasi ini (untuk cek update; naik tiap rilis).
const int kAppVersionCode = 5;

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
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
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
        final glass = ref.read(userThemeProvider).preset == ThemePreset.glass;
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: glass ? Colors.transparent : null,
          barrierColor: glass ? Colors.black.withValues(alpha: .30) : null,
          builder: (_) => const AccountSheet(),
        ).then((_) {
          final current = ref.read(sessionProvider);
          if (current.status == SessionStatus.gate && !current.loginSkipped) {
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
        final theme = ref.read(userThemeProvider);
        final isGlass = theme.preset == ThemePreset.glass;
        final isLight = theme.isLight;
        if (isGlass) {
          showLiquidGlassDialog<void>(
            context: context,
            isLight: isLight,
            barrierDismissible: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(FontAwesomeIcons.userLock, size: 32, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 14),
                  Text(
                    next.blockedTitle.isEmpty ? 'Akses akun dinonaktifkan' : next.blockedTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    next.blockedMessage.isEmpty ? 'Hubungi administrator jika memerlukan bantuan.' : next.blockedMessage,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: () => Sfx.play('error'), child: const Text('Mengerti')),
                  ),
                ],
              ),
            ),
          ).then((_) => _blockedDialogOpen = false);
        } else {
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => PopScope(
              canPop: false,
              child: AlertDialog(
                icon: const FaIcon(FontAwesomeIcons.userLock),
                title: Text(next.blockedTitle.isEmpty ? 'Akses akun dinonaktifkan' : next.blockedTitle),
                content: Text(next.blockedMessage.isEmpty ? 'Hubungi administrator jika memerlukan bantuan.' : next.blockedMessage),
                actions: [
                  FilledButton(onPressed: () => Sfx.play('error'), child: const Text('Mengerti')),
                ],
              ),
            ),
          ).then((_) => _blockedDialogOpen = false);
        }
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
    final theme = ref.read(userThemeProvider);
    final glass = theme.preset == ThemePreset.glass;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: glass ? Colors.transparent : null,
      barrierColor: glass ? Colors.black.withValues(alpha: theme.isLight ? .14 : .30) : null,
      builder: (_) => sheet,
    );
  }

  Future<void> _confirmDelete(String day, int index, String name) async {
    final theme = ref.read(userThemeProvider);
    final isGlass = theme.preset == ThemePreset.glass;
    final isLight = theme.isLight;
    bool? confirmed;
    if (isGlass) {
      confirmed = await showLiquidGlassDialog<bool>(
        context: context,
        isLight: isLight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(FontAwesomeIcons.trashCan, size: 28, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              const Text('Hapus Jadwal?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Hapus "$name" dari hari $day?', textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal'))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Hapus'))),
              ]),
            ],
          ),
        ),
      );
    } else {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const FaIcon(FontAwesomeIcons.trashCan),
          title: const Text('Hapus Jadwal?'),
          content: Text('Hapus "$name" dari hari $day?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Hapus')),
          ],
        ),
      );
    }
    if (confirmed == true) {
      await ref.read(scheduleProvider.notifier).deleteLesson(day, index);
    }
  }

  Future<void> _confirmClearAll() async {
    final theme = ref.read(userThemeProvider);
    final isGlass = theme.preset == ThemePreset.glass;
    final isLight = theme.isLight;
    bool? confirmed;
    if (isGlass) {
      confirmed = await showLiquidGlassDialog<bool>(
        context: context,
        isLight: isLight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(FontAwesomeIcons.trashCan, size: 28, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              const Text('Kosongkan Semua?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Semua jadwal di semua hari akan dihapus. Tindakan ini tidak bisa dibatalkan.', textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal'))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Hapus'))),
              ]),
            ],
          ),
        ),
      );
    } else {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const FaIcon(FontAwesomeIcons.trashCan),
          title: const Text('Kosongkan Semua?'),
          content: const Text('Semua jadwal di semua hari akan dihapus. Tindakan ini tidak bisa dibatalkan.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Hapus')),
          ],
        ),
      );
    }
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
    final userTheme = ref.watch(userThemeProvider);
    final glass = userTheme.preset == ThemePreset.glass;
    final isLight = userTheme.isLight;

    if (session.status == SessionStatus.boot) {
      return Scaffold(
        backgroundColor: glass ? (isLight ? kGlassScaffoldLight : kGlassScaffoldDark) : null,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (session.status == SessionStatus.locked) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: glass ? (isLight ? kGlassScaffoldLight : kGlassScaffoldDark) : null,
          body: _DeviceLockOverlay(isLight: isLight, glass: glass),
        ),
      );
    }

    final today = _todayName();
    final maintenance = config.valueOrNull?.maintenance;
    final showMaintenance = maintenance?.enabled ?? false;
    final update = config.valueOrNull?.update;
    final showUpdate = update != null && update.enabled && update.versionCode > kAppVersionCode && update.apkUrl.isNotEmpty;

    if (showMaintenance) {
      return Scaffold(
        backgroundColor: glass ? (isLight ? kGlassScaffoldLight : kGlassScaffoldDark) : null,
        body: _MaintenanceOverlay(
          title: maintenance?.title ?? 'Aplikasi sedang diperbaiki',
          message: maintenance?.message ?? '',
          isLight: isLight,
          glass: glass,
        ),
      );
    }

    if (!showUpdate && _updateDismissed) _updateDismissed = false;
    final forceUpdate = showUpdate && update.force;
    if (forceUpdate) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: glass ? (isLight ? kGlassScaffoldLight : kGlassScaffoldDark) : null,
          body: _UpdateOverlay(update: update, downloader: _downloader, isLight: isLight, glass: glass),
        ),
      );
    }

    // Scaffold utama — glass menggunakan backdrop tunggal (1 blur) di Stack.
    return Scaffold(
      backgroundColor: glass ? (isLight ? kGlassScaffoldLight : kGlassScaffoldDark) : null,
      body: SafeArea(
        child: Stack(
          children: [
            if (glass) ...[
              GlassBackground(isLight: isLight),
              const GlassBackdrop(sigma: kGlassBlur),
            ],
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(child: _header(session, glass: glass, isLight: isLight)),
                if (_menuOpen)
                  SliverToBoxAdapter(
                    child: _MenuPanel(onData: () => _openSheet(const DataSheet()), glass: glass, isLight: isLight),
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
                      isLight: isLight,
                      countdown: day == today
                          ? nextLessonToday(
                              schedule.data.days[day] ?? const <String>[],
                              schedule.startTime,
                              DateTime.now(),
                            )
                          : null,
                      onAdd: () => _openSheet(InputSheet(day: day)),
                      onEdit: (index) => _openSheet(InputSheet(day: day, index: index)),
                      onDelete: (index) => _confirmDelete(day, index, schedule.data.days[day]![index]),
                    ),
                  ),
                if (!schedule.locked && !schedule.data.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      child: glass
                          ? LiquidGlassCard(
                              isLight: isLight,
                              radius: 16,
                              child: SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: _confirmClearAll,
                                  icon: FaIcon(FontAwesomeIcons.trashCan, size: 15, color: Theme.of(context).colorScheme.error),
                                  label: Text('Kosongkan Semua', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                ),
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: _confirmClearAll,
                              icon: const FaIcon(FontAwesomeIcons.trashCan, size: 15),
                              label: const Text('Kosongkan Semua'),
                            ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
            if (showUpdate && !forceUpdate)
              Positioned.fill(
                child: _UpdateOverlay(update: update, downloader: _downloader, isLight: isLight, glass: glass, onDismissed: () => setState(() => _updateDismissed = true)),
              ),
          ],
        ),
      ),
      floatingActionButton: (showUpdate && !_updateDismissed)
          ? null
          : glass
              ? LiquidGlassFab(
                  isLight: isLight,
                  onPressed: () {
                    final day = today.isEmpty ? kDays.first : today;
                    _openSheet(InputSheet(day: day));
                  },
                  child: FaIcon(FontAwesomeIcons.plus, size: 18, color: isLight ? Theme.of(context).colorScheme.primary : Colors.white),
                )
              : FloatingActionButton(
                  onPressed: () {
                    final day = today.isEmpty ? kDays.first : today;
                    _openSheet(InputSheet(day: day));
                  },
                  child: const FaIcon(FontAwesomeIcons.plus),
                ),
    );
  }

  Widget _header(SessionState session, {required bool glass, required bool isLight}) {
    final customPhoto = ref.watch(customPhotoProvider);
    final avatar = customPhoto.isNotEmpty ? customPhoto : session.photo;
    final scheme = Theme.of(context).colorScheme;
    final inner = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _openSheet(const AccountSheet()),
            child: CircleAvatar(
              radius: 22,
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              onBackgroundImageError: avatar.isNotEmpty ? (_, _) {} : null,
              child: avatar.isEmpty ? const FaIcon(FontAwesomeIcons.user, size: 18) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_todayLabel(), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text(_dateDetail(), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: _menuOpen ? 'Sembunyikan menu' : 'Buka menu',
            onPressed: () {
              Sfx.play('click');
              setState(() => _menuOpen = !_menuOpen);
            },
            style: IconButton.styleFrom(
              backgroundColor: glass
                  ? (isLight ? Colors.white.withValues(alpha: .65) : Colors.white.withValues(alpha: .10))
                  : scheme.surfaceContainerHighest.withValues(alpha: .55),
            ),
            icon: FaIcon(_menuOpen ? FontAwesomeIcons.chevronUp : FontAwesomeIcons.ellipsis, size: 16),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: glass
          ? LiquidGlassCard(isLight: isLight, radius: 22, padding: const EdgeInsets.all(0), child: inner)
          : Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: .38)),
              ),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _openSheet(const AccountSheet()),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      onBackgroundImageError: avatar.isNotEmpty ? (_, _) {} : null,
                      child: avatar.isEmpty ? const FaIcon(FontAwesomeIcons.user, size: 18) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_todayLabel(), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        Text(_dateDetail(), style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _menuOpen ? 'Sembunyikan menu' : 'Buka menu',
                    onPressed: () {
                      Sfx.play('click');
                      setState(() => _menuOpen = !_menuOpen);
                    },
                    style: IconButton.styleFrom(backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: .55)),
                    icon: FaIcon(_menuOpen ? FontAwesomeIcons.chevronUp : FontAwesomeIcons.ellipsis, size: 16),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Panel menu — glass pill jika mode glass.
class _MenuPanel extends ConsumerWidget {
  const _MenuPanel({required this.onData, required this.glass, required this.isLight});

  final VoidCallback onData;
  final bool glass;
  final bool isLight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(scheduleProvider.select((s) => s.locked));
    final buttons = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton.filledTonal(
          onPressed: onData,
          icon: const FaIcon(FontAwesomeIcons.folderOpen, size: 16),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () => ref.read(scheduleProvider.notifier).toggleLock(),
          icon: Icon(locked ? Icons.lock : Icons.lock_open, color: locked ? Colors.red : null, size: 18),
        ),
      ],
    );
    if (!glass) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: buttons);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: LiquidGlassCard(
          isLight: isLight,
          radius: 999,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _GlassIconButton(icon: FontAwesomeIcons.folderOpen, onPressed: onData, isLight: isLight),
            const SizedBox(width: 8),
            _GlassIconButton(icon: locked ? FontAwesomeIcons.lock : FontAwesomeIcons.lockOpen, color: locked ? Colors.red : null, onPressed: () => ref.read(scheduleProvider.notifier).toggleLock(), isLight: isLight),
          ]),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onPressed, this.color, required this.isLight});

  final FaIconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isLight ? Colors.white.withValues(alpha: .70) : Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: FaIcon(icon, size: 15, color: color),
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
    required this.isLight,
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
  final bool isLight;
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
            Expanded(child: Text(day, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            if (isToday)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: glass
                      ? (isLight ? scheme.primary.withValues(alpha: .14) : scheme.primary)
                      : scheme.primary,
                  borderRadius: BorderRadius.circular(999),
                  border: glass && isLight ? Border.all(color: scheme.primary.withValues(alpha: .18)) : null,
                ),
                child: Text('Hari Ini', style: TextStyle(color: glass && isLight ? scheme.primary : scheme.onPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        if (countdown != null) ...[
          const SizedBox(height: 8),
          glass
              ? LiquidGlassInset(
                  isLight: isLight,
                  child: Row(children: [
                    FaIcon(FontAwesomeIcons.clock, size: 14, color: isLight ? scheme.primary : Colors.white.withValues(alpha: .92)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'Pelajaran berikutnya: '),
                          TextSpan(text: countdown!.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                          TextSpan(text: ' (${countdownText(countdown!.minutesLeft)})'),
                        ]),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ]),
                )
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const FaIcon(FontAwesomeIcons.clock, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'Pelajaran berikutnya: '),
                          TextSpan(text: countdown!.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                          TextSpan(text: ' (${countdownText(countdown!.minutesLeft)})'),
                        ]),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ]),
                ),
        ],
        const SizedBox(height: 6),
        if (lessons.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Opacity(opacity: 0.4, child: Text('Tidak ada jadwal', style: TextStyle(fontSize: 13)))),
          )
        else
          for (var i = 0; i < lessons.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scheme.primary.withValues(alpha: isLight && glass ? .14 : 0.14), shape: BoxShape.circle),
                  child: Text('${i + 1}', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(lessons[i])),
                if (!locked) ...[
                  IconButton(onPressed: () => onEdit(i), icon: const FaIcon(FontAwesomeIcons.pencil, size: 15)),
                  IconButton(onPressed: () => onDelete(i), icon: FaIcon(FontAwesomeIcons.trash, size: 15, color: scheme.error)),
                ],
              ]),
            ),
        if (!locked)
          TextButton.icon(onPressed: onAdd, icon: const FaIcon(FontAwesomeIcons.circlePlus, size: 15), label: const Text('Tambah Pelajaran')),
      ],
    );
    final body = Padding(padding: const EdgeInsets.all(16), child: content);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: glass
          ? LiquidGlassCard(isLight: isLight, radius: 22, child: body)
          : Card(color: isToday ? scheme.primaryContainer : null, child: body),
    );
  }
}

class _MaintenanceOverlay extends StatelessWidget {
  const _MaintenanceOverlay({required this.title, required this.message, required this.isLight, required this.glass});

  final String title;
  final String message;
  final bool isLight;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(22)),
            child: const Icon(Icons.handyman_outlined, size: 38, color: Colors.white),
          ),
          const SizedBox(height: 22),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: isLight ? const Color(0xFF0A0E1A) : const Color(0xFFF7F9FF), fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: isLight ? const Color(0xFF5A6A85) : const Color(0xFF97AAC8), fontSize: 14, height: 1.7)),
        ]),
      ),
    );
    if (!glass) {
      return Container(color: const Color(0xFF080C18), padding: const EdgeInsets.all(28), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [card]));
    }
    return Stack(children: [
      Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: isLight ? Colors.white.withValues(alpha: .82) : const Color(0xFF0A0E1A).withValues(alpha: .88)))),
      const GlassBackdrop(sigma: 18),
      Center(child: LiquidGlassCard(isLight: isLight, radius: 28, child: card)),
    ]);
  }
}

class _UpdateOverlay extends StatefulWidget {
  const _UpdateOverlay({required this.update, required this.downloader, this.onDismissed, required this.isLight, required this.glass});
  final UpdateConfig update;
  final UpdateDownloader downloader;
  final VoidCallback? onDismissed;
  final bool isLight;
  final bool glass;
  @override
  State<_UpdateOverlay> createState() => _UpdateOverlayState();
}

class _UpdateOverlayState extends State<_UpdateOverlay> {
  bool _dismissed = false;
  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final update = widget.update;
    final force = update.force;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(22)),
            child: const Icon(Icons.download_outlined, size: 36, color: Colors.white),
          ),
          const SizedBox(height: 22),
          Text(update.title, textAlign: TextAlign.center, style: TextStyle(color: widget.isLight ? const Color(0xFF0A0E1A) : const Color(0xFFF7F9FF), fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text(update.message, textAlign: TextAlign.center, style: TextStyle(color: widget.isLight ? const Color(0xFF5A6A85) : const Color(0xFF97AAC8), fontSize: 14, height: 1.7)),
          const SizedBox(height: 22),
          ListenableBuilder(
            listenable: widget.downloader,
            builder: (context, _) {
              final d = widget.downloader;
              final downloading = d.status == UpdateDownloadStatus.downloading;
              final error = d.status == UpdateDownloadStatus.error;
              final needsUninstall = d.status == UpdateDownloadStatus.needsUninstall;
              if (needsUninstall) {
                return Column(children: [
                  Text('APK versi ${d.archiveCode} valid, tapi versi ${d.installedCode} sudah terpasang. Hapus versi lama lalu pasang dari folder Download?', textAlign: TextAlign.center, style: TextStyle(color: widget.isLight ? const Color(0xFF5A6A85) : const Color(0xFF97AAC8), fontSize: 13)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () async { await d.uninstallOld(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Setelah terhapus, buka file APK di folder Download untuk memasang.'))); }, child: const Text('Hapus versi lama')),
                  if (!force) TextButton(onPressed: () { setState(() => _dismissed = true); widget.onDismissed?.call(); }, child: Text('Nanti saja', style: TextStyle(color: widget.isLight ? const Color(0xFF5A6A85) : const Color(0xFF97AAC8)))),
                ]);
              }
              return Column(children: [
                if (downloading && d.progress != null) ...[
                  LinearProgressIndicator(value: d.progress),
                  const SizedBox(height: 8),
                  Text('${((d.progress ?? 0) * 100).round()}%', style: TextStyle(color: widget.isLight ? const Color(0xFF5A6A85) : const Color(0xFF97AAC8), fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: downloading ? null : () async { final err = await d.downloadAndOpen(update.apkUrl, update.versionName); if (err != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err))); },
                  child: Text(downloading ? 'Sedang mengunduh...' : (error ? 'Coba unduh lagi' : 'Unduh & Pasang')),
                ),
                if (!force) TextButton(onPressed: () { setState(() => _dismissed = true); widget.onDismissed?.call(); }, child: Text('Nanti saja', style: TextStyle(color: widget.isLight ? const Color(0xFF5A6A85) : const Color(0xFF97AAC8)))),
              ]);
            },
          ),
        ]),
      ),
    );
    if (!widget.glass) {
      return Container(color: const Color(0xFF060B16), child: Center(child: SingleChildScrollView(child: content)));
    }
    final sheet = LiquidGlassCard(isLight: widget.isLight, radius: 28, child: SingleChildScrollView(child: content));
    if (force) {
      return Stack(children: [Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: widget.isLight ? Colors.white.withValues(alpha: .84) : const Color(0xFF0A0E1A).withValues(alpha: .90)))), const GlassBackdrop(sigma: 18), Center(child: Padding(padding: const EdgeInsets.all(20), child: sheet))]);
    }
    return LiquidGlassFullscreen(isLight: widget.isLight, child: Padding(padding: const EdgeInsets.all(20), child: sheet));
  }
}

/// Popup blokir perangkat: TENGAH layar, TANPA tombol, tidak bisa dihilangkan.
class _DeviceLockOverlay extends StatelessWidget {
  const _DeviceLockOverlay({required this.isLight, required this.glass});
  final bool isLight;
  final bool glass;
  @override
  Widget build(BuildContext context) {
    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12)),
            child: Icon(Icons.block_outlined, size: 30, color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 14),
          Text('PERANGKAT DIBLOKIR', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
          const SizedBox(height: 10),
          Text('Perangkat ini diblokir', textAlign: TextAlign.center, style: TextStyle(color: isLight ? const Color(0xFF0A0E1A) : Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Perangkat ini tidak diizinkan mengakses Jadwal Pintar. Hubungi administrator.', textAlign: TextAlign.center, style: TextStyle(color: isLight ? const Color(0xFF5A6A85) : const Color(0xFF97AAC8), fontSize: 13)),
        ]),
      ),
    );
    if (!glass) {
      return Container(color: const Color(0xFF04060C), padding: const EdgeInsets.all(28), child: Center(child: Container(padding: const EdgeInsets.fromLTRB(24, 30, 24, 30), decoration: BoxDecoration(color: const Color(0xFF10141F), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0x1FFFFFFF))), child: card)));
    }
    return Stack(children: [
      Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: isLight ? Colors.white.withValues(alpha: .88) : const Color(0xFF04060C)))),
      const GlassBackdrop(sigma: 20),
      Center(child: LiquidGlassCard(isLight: isLight, radius: 24, child: card)),
    ]);
  }
}
