import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/sfx.dart';
import '../widgets.dart';

String _formatTime(int millis) {
  if (millis <= 0) return '-';
  final date = DateTime.fromMillisecondsSinceEpoch(millis);
  const months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final day = '${date.day}'.padLeft(2, '0');
  final hour = '${date.hour}'.padLeft(2, '0');
  final minute = '${date.minute}'.padLeft(2, '0');
  return '$day ${months[date.month - 1]} $hour:$minute';
}

/// Halaman pengguna: cari, kartu status, dialog detail + kontrol akses/ban.
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      setState(() => _query = _search.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(profilesProvider)
      ..invalidate(accessMapProvider)
      ..invalidate(bansProvider);
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);
    final access = ref.watch(accessMapProvider);
    final bans = ref.watch(bansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengguna')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Cari nama atau email',
                prefixIcon: Icon(Icons.search_outlined),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: profiles.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    EmptyState(text: 'Gagal memuat pengguna: $e')
                  ],
                ),
                data: (users) {
                  final accessMap = access.valueOrNull ?? const {};
                  final list = users.values.toList()
                    ..sort((a, b) =>
                        b.lastLoginAt.compareTo(a.lastLoginAt));
                  final filtered = _query.isEmpty
                      ? list
                      : list
                          .where((u) => u
                              .searchableText()
                              .toLowerCase()
                              .contains(_query))
                          .toList();
                  final online =
                      users.values.where((u) => u.isOnlineNow()).length;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Pengguna: ${users.length} • Online: $online',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      if (filtered.isEmpty)
                        const EmptyState(
                          text: 'Tidak ada pengguna yang cocok.',
                        ),
                      for (final user in filtered) ...[
                        _UserCard(
                          user: user,
                          access:
                              accessMap[user.uid] ?? const UserAccess(),
                          banned: bans.valueOrNull
                                  ?.containsKey(user.deviceIdHash) ??
                              false,
                          onTap: () => _showDetail(context, ref, user),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetail(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
  ) async {
    final accessMap = ref.read(accessMapProvider).valueOrNull ?? const {};
    final entry = accessMap[user.uid] ?? const UserAccess();
    final bans = ref.read(bansProvider).valueOrNull ?? const {};
    final banned = bans.containsKey(user.deviceIdHash);
    final online = user.isOnlineNow();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(child: Text(_initials(user.name))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('UID', user.uid),
              _row('Dibuat', _formatTime(user.createdAt)),
              _row('Login terakhir', _formatTime(user.lastLoginAt)),
              _row('Terakhir terlihat', _formatTime(user.lastSeenAt)),
              _row('Koneksi', online ? 'Online' : 'Offline'),
              _row('Akses',
                  entry.enabled ? 'Diizinkan' : 'Dinonaktifkan'),
              _row('Versi', user.appVersion),
              _row('Perangkat', user.deviceModel),
              _row('OS', user.osVersion),
              _row(
                'Device ID',
                user.deviceIdHash.isEmpty
                    ? (user.deviceIdMissing
                        ? 'tidak terbaca (perlu diperiksa)'
                        : '-')
                    : user.shortDeviceId(),
              ),
              _row('Status perangkat',
                  banned ? 'DIBLOKIR' : 'Bersih'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
          TextButton(
            onPressed: user.deviceIdHash.isEmpty
                ? null
                : () {
                    Navigator.of(dialogContext).pop();
                    _toggleBan(ref, user, banned);
                  },
            child: Text(
              banned ? 'Buka blokir perangkat' : 'Blokir perangkat',
              style: TextStyle(
                color: banned ? Colors.green : Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _toggleAccess(ref, user, !entry.enabled);
            },
            child: Text(
              entry.enabled ? 'Nonaktifkan' : 'Aktifkan akses',
              style: TextStyle(
                color: entry.enabled
                    ? Theme.of(context).colorScheme.error
                    : Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Future<void> _toggleAccess(
    WidgetRef ref,
    UserProfile user,
    bool enabled,
  ) async {
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) return;
    final db = ref.read(databaseProvider);
    try {
      await db.setUserAccess(
        user.uid,
        enabled: enabled,
        by: admin.uid,
      );
      await db.writeAudit(
        adminUid: admin.uid,
        adminEmail: admin.email ?? '',
        action: '${enabled ? 'enable_user_' : 'disable_user_'}${user.uid}',
      );
      await Sfx.play('success');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Akses ${user.name} ${enabled ? 'diaktifkan' : 'dinonaktifkan'}.',
          ),
        ),
      );
    } catch (e) {
      await Sfx.play('error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  Future<void> _toggleBan(
    WidgetRef ref,
    UserProfile user,
    bool banned,
  ) async {
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null || user.deviceIdHash.isEmpty) return;
    final db = ref.read(databaseProvider);
    try {
      if (banned) {
        await db.removeDeviceBan(user.deviceIdHash);
        await db.writeAudit(
          adminUid: admin.uid,
          adminEmail: admin.email ?? '',
          action: 'unban_device_${user.uid}',
        );
      } else {
        await db.setDeviceBan(user.deviceIdHash, <String, Object?>{
          'banned': true,
          'uid': user.uid,
          'name': user.name,
          'email': user.email,
          'deviceModel': user.deviceModel,
          'createdAt':
              DateTime.now().millisecondsSinceEpoch,
          'createdBy': admin.uid,
        });
        await db.writeAudit(
          adminUid: admin.uid,
          adminEmail: admin.email ?? '',
          action: 'ban_device_${user.uid}',
        );
      }
      await Sfx.play('success');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            banned
                ? 'Blokir perangkat ${user.name} dibuka.'
                : 'Perangkat ${user.name} diblokir.',
          ),
        ),
      );
    } catch (e) {
      await Sfx.play('error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.access,
    required this.banned,
    required this.onTap,
  });

  final UserProfile user;
  final UserAccess access;
  final bool banned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final online = user.isOnlineNow();
    final scheme = Theme.of(context).colorScheme;
    final String statusText;
    final Color statusColor;
    if (!access.enabled) {
      statusText = 'DIBLOKIR';
      statusColor = scheme.error;
    } else if (banned) {
      statusText = 'PERANGKAT DIBLOKIR';
      statusColor = scheme.error;
    } else if (online) {
      statusText = 'ONLINE';
      statusColor = Colors.green;
    } else {
      statusText = 'OFFLINE';
      statusColor = scheme.onSurfaceVariant;
    }
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Sfx.play('click');
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(child: Text(_initials(user.name))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${user.deviceModel} • v${user.appVersion}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Login ${_formatTime(user.lastLoginAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusChip(text: statusText, color: statusColor),
            ],
          ),
        ),
      ),
    );
  }
}
