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

/// Halaman khusus perangkat diblokir + buka blokir.
class BannedScreen extends ConsumerWidget {
  const BannedScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(bansProvider);
    ref.invalidate(profilesProvider);
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _confirmUnban(
    BuildContext context,
    WidgetRef ref,
    String hash,
    DeviceBan ban,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buka blokir perangkat'),
        content: Text(
          'Perangkat milik ${ban.name.isEmpty ? 'pengguna' : ban.name} '
          'bisa dipakai lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Buka blokir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) return;
    try {
      final db = ref.read(databaseProvider);
      await db.removeDeviceBan(hash);
      await db.writeAudit(
        adminUid: admin.uid,
        adminEmail: admin.email ?? '',
        action: 'unban_device_hash_$hash',
      );
      await Sfx.play('success');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blokir perangkat dibuka.')),
      );
    } catch (e) {
      await Sfx.play('error');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka blokir: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bans = ref.watch(bansProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Perangkat Diblokir')),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: bans.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [EmptyState(text: 'Gagal memuat: $e')],
          ),
          data: (items) {
            final entries = items.entries.toList();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Diblokir: ${entries.length}',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ketuk kartu untuk membuka blokir perangkat.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                if (entries.isEmpty)
                  const EmptyState(
                    text: 'Belum ada perangkat yang diblokir.',
                  ),
                for (final entry in entries)
                  _BannedCard(
                    hash: entry.key,
                    ban: entry.value,
                    onTap: () =>
                        _confirmUnban(context, ref, entry.key, entry.value),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BannedCard extends StatelessWidget {
  const _BannedCard({
    required this.hash,
    required this.ban,
    required this.onTap,
  });

  final String hash;
  final DeviceBan ban;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = ban.name.isEmpty ? 'Perangkat tak dikenal' : ban.name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
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
                CircleAvatar(
                  child: Text(
                    name.characters.take(2).toString().toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        ban.email,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${ban.deviceModel.isEmpty ? '-' : ban.deviceModel} • ID: '
                        '${hash.length >= 12 ? '${hash.substring(0, 12)}…' : '-'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Diblokir ${_formatTime(ban.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusChip(text: 'DIBLOKIR', color: scheme.error),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
