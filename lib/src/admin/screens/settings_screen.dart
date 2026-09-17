import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/sfx.dart';
import '../widgets.dart';

/// Halaman pengaturan: workspace, info aplikasi, keluar.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final user = auth.valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Administrator',
            subtitle: 'Akun yang sedang dipakai di perangkat ini.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Administrator',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                SelectableText(user?.email ?? ''),
                SelectableText('UID: ${user?.uid ?? '-'}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SectionCard(
            title: 'Workspace',
            subtitle: 'Jadwal Pintar Production. Realtime Database + '
                'Firebase Storage. Role: Super Administrator.',
            child: SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          const SectionCard(
            title: 'Aplikasi',
            subtitle: 'Admin Flutter v3.0.0+3. Project: jadwal-pintar.',
            child: SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () async {
              await Sfx.play('click');
              await ref.read(authServiceProvider).signOut();
            },
            icon: const Icon(Icons.logout_outlined),
            label: const Text('Keluar dari akun admin'),
          ),
        ],
      ),
    );
  }
}
