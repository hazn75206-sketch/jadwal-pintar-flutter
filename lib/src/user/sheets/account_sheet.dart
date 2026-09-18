import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/providers.dart';
import '../../core/prefs.dart';
import '../../core/sfx.dart';
import '../schedule_provider.dart';
import '../session.dart';
import '../user_theme_provider.dart';
import 'glass_panel.dart';
import 'info_sheets.dart';
import 'theme_sheet.dart';

/// Foto profil custom milik akun ini (menang atas foto Google).
final customPhotoProvider = StateProvider<String>((_) => '');

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String formatLastSync(String iso) {
  if (iso.isEmpty) return 'Belum pernah';
  try {
    final date = DateTime.parse(iso);
    final day = '${date.day}'.padLeft(2, '0');
    final hour = '${date.hour}'.padLeft(2, '0');
    final minute = '${date.minute}'.padLeft(2, '0');
    return '$day ${_months[date.month - 1]} ${date.year} • $hour:$minute';
  } catch (_) {
    return 'Belum pernah';
  }
}

/// Modal akun / login (cermin #accountModal): loginView + profileView.
class AccountSheet extends ConsumerStatefulWidget {
  const AccountSheet({super.key});

  @override
  ConsumerState<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<AccountSheet> {
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadCustomPhoto();
  }

  Future<void> _loadCustomPhoto() async {
    try {
      final prefs = await ref.read(prefsProvider.future);
      final local = prefs.getString(PrefKeys.customPhoto) ?? '';
      if (local.isNotEmpty) {
        ref.read(customPhotoProvider.notifier).state = local;
        return;
      }
      final uid = ref.read(authServiceProvider).current?.uid;
      if (uid == null) return;
      final remote =
          await ref.read(databaseProvider).loadProfilePhoto(uid);
      if (remote.isNotEmpty) {
        await prefs.setString(PrefKeys.customPhoto, remote);
        if (mounted) {
          ref.read(customPhotoProvider.notifier).state = remote;
        }
      }
    } catch (_) {}
  }

  Future<void> _doLogin() async {
    setState(() {
      _busy = true;
      _status = '';
    });
    final error =
        await ref.read(sessionProvider.notifier).loginWithGoogle();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = error ?? '';
    });
    if (error == null) {
      await Sfx.play('success');
      if (!mounted) return;
      Navigator.of(context).pop();
    } else if (error.contains('diblokir')) {
      // Toast untuk penolakan login di perangkat banned (aturan user).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  Future<void> _pickPhoto() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    final file = files.first;
    List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      return;
    }
    if (bytes.length > 350 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto maksimal 350 KB')),
      );
      return;
    }
    var ext = file.extension ?? 'jpeg';
    if (ext == 'jpg') ext = 'jpeg';
    final dataUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';
    ref.read(customPhotoProvider.notifier).state = dataUrl;
    try {
      final prefs = await ref.read(prefsProvider.future);
      await prefs.setString(PrefKeys.customPhoto, dataUrl);
      final uid = ref.read(authServiceProvider).current?.uid;
      if (uid != null) {
        await ref.read(databaseProvider).saveProfilePhoto(uid, dataUrl);
      }
    } catch (_) {}
    await Sfx.play('success');
  }

  Future<void> _resetPhoto() async {
    ref.read(customPhotoProvider.notifier).state = '';
    try {
      final prefs = await ref.read(prefsProvider.future);
      await prefs.remove(PrefKeys.customPhoto);
      final uid = ref.read(authServiceProvider).current?.uid;
      if (uid != null) {
        await ref.read(databaseProvider).saveProfilePhoto(uid, '');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final loggedIn = session.status == SessionStatus.loggedIn &&
        (session.name.isNotEmpty || session.email.isNotEmpty);
    return GlassPanel(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: loggedIn
                ? _profileView(context, ref, session)
                : _loginView(),
          ),
        ),
      ),
    );
  }

  Widget _loginView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const FaIcon(FontAwesomeIcons.cloud, size: 44),
        const SizedBox(height: 12),
        Text(
          'Simpan di Cloud',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Masuk dengan akun Google agar jadwal Anda\ntersimpan aman & tidak akan hilang.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        const _BenefitRow(
            icon: FontAwesomeIcons.shieldHalved,
            text: 'Data aman di akun Google Anda'),
        const _BenefitRow(
            icon: FontAwesomeIcons.rotate,
            text: 'Sinkron otomatis setiap perubahan'),
        const _BenefitRow(
            icon: FontAwesomeIcons.mobileScreen,
            text: 'Pulihkan di HP baru dengan sekali login'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _doLogin,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const FaIcon(FontAwesomeIcons.google, size: 18),
          label: Text(_busy ? 'Memverifikasi…' : 'Masuk dengan Google'),
        ),
        TextButton(
          onPressed: () {
            ref.read(sessionProvider.notifier).skipLogin();
            Navigator.of(context).pop();
          },
          child: const Text('Lewati, gunakan tanpa akun'),
        ),
        if (_status.isNotEmpty)
          Text(
            _status,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  Widget _profileView(
      BuildContext context, WidgetRef ref, SessionState session) {
    final customPhoto = ref.watch(customPhotoProvider);
    final schedule = ref.watch(scheduleProvider);
    final photo = customPhoto.isNotEmpty ? customPhoto : session.photo;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 38,
              backgroundImage:
                  photo.isNotEmpty ? NetworkImage(photo) : null,
              onBackgroundImageError: photo.isNotEmpty ? (_, _) {} : null,
              child: photo.isEmpty
                  ? const FaIcon(FontAwesomeIcons.user, size: 30)
                  : null,
            ),
            IconButton.filledTonal(
              onPressed: _pickPhoto,
              icon: const FaIcon(FontAwesomeIcons.camera, size: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          session.name.isEmpty ? 'Pengguna' : session.name,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(session.email),
        const SizedBox(height: 8),
        _SyncBadge(badge: schedule.badge),
        if (customPhoto.isNotEmpty)
          TextButton.icon(
            onPressed: _resetPhoto,
            icon: const FaIcon(FontAwesomeIcons.rotateLeft, size: 14),
            label: const Text('Kembalikan foto Google'),
          ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const FaIcon(FontAwesomeIcons.cloud),
            title: const Text('Cloud'),
            subtitle: Text(
              'Data Anda tersimpan aman di cloud\nTerakhir sinkron: '
              '${formatLastSync(schedule.lastSync)}',
            ),
            trailing: const FaIcon(FontAwesomeIcons.check, size: 16),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => ref
                    .read(scheduleProvider.notifier)
                    .syncNow(),
                icon: const FaIcon(FontAwesomeIcons.rotate, size: 15),
                label: const Text('Sinkronkan'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => ref
                    .read(scheduleProvider.notifier)
                    .restoreFromCloud(),
                icon: const FaIcon(FontAwesomeIcons.cloudArrowDown,
                    size: 15),
                label: const Text('Pulihkan'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SettingRow(
          icon: FontAwesomeIcons.user,
          label: 'Edit Profil',
          onTap: _pickPhoto,
        ),
        _SettingRow(
          icon: FontAwesomeIcons.palette,
          label: 'Tema',
          onTap: () => _openSheet(const ThemeSheet()),
        ),
        _SettingRow(
          icon: FontAwesomeIcons.shieldHalved,
          label: 'Privasi',
          onTap: () => _openSheet(const PrivacySheet()),
        ),
        _SettingRow(
          icon: FontAwesomeIcons.cloud,
          label: 'Penyimpanan Cloud',
          onTap: () => _openSheet(const CloudInfoSheet()),
        ),
        _SettingRow(
          icon: FontAwesomeIcons.circleInfo,
          label: 'Tentang',
          onTap: () => _openSheet(const InfoSheet()),
        ),
        _SettingRow(
          icon: FontAwesomeIcons.rightFromBracket,
          label: 'Keluar',
          danger: true,
          onTap: () {
            ref.read(sessionProvider.notifier).logout();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  void _openSheet(Widget sheet) {
    final glass =
        ref.read(userThemeProvider).preset == ThemePreset.glass;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: glass ? Colors.transparent : null,
      builder: (_) => sheet,
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});

  final FaIconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          FaIcon(icon, size: 15),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.badge});

  final SyncBadge badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final String text;
    final Color color;
    final IconData icon;
    switch (badge) {
      case SyncBadge.syncing:
        text = 'Menyinkronkan...';
        color = Colors.orange;
        icon = Icons.sync;
        break;
      case SyncBadge.error:
        text = 'Gagal sinkron';
        color = scheme.error;
        icon = Icons.warning_outlined;
        break;
      case SyncBadge.ok:
      case SyncBadge.idle:
        text = 'Sinkron Aktif';
        color = Colors.green;
        icon = Icons.circle;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: FaIcon(
        icon,
        size: 17,
        color: danger ? Theme.of(context).colorScheme.error : null,
      ),
      title: Text(label),
      trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 14),
      onTap: () {
        Sfx.play('click');
        onTap();
      },
    );
  }
}

/// Info kartu Cloud (ringkas).
class CloudInfoSheet extends StatelessWidget {
  const CloudInfoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(FontAwesomeIcons.cloud, size: 30),
            const SizedBox(height: 10),
            Text(
              'Penyimpanan Cloud',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Jadwal dan foto profil tersimpan di akun Google Anda '
              'dan tersinkron otomatis antar perangkat.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      ),
    );
  }
}
