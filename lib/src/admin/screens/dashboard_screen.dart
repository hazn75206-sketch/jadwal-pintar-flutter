import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../widgets.dart';

/// Dashboard: angka kunci + status layanan. Tarik-bawah untuk refresh.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(profilesProvider)
      ..invalidate(accessMapProvider)
      ..invalidate(bansProvider)
      ..invalidate(appConfigProvider);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final access = ref.watch(accessMapProvider);
    final bans = ref.watch(bansProvider);
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Desk')),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .28),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: .16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.space_dashboard_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Desk',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Pantau layanan dan pengguna dari satu tempat.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            profiles.when(
              loading: () => const _StatsLoading(),
              error: (e, _) => EmptyState(text: 'Gagal memuat pengguna: $e'),
              data: (users) {
                final online =
                    users.values.where((u) => u.isOnlineNow()).length;
                final accessMap = access.valueOrNull ?? const {};
                final banned = bans.valueOrNull ?? const {};
                final maintenanceOn =
                    config.valueOrNull?.maintenance.enabled ?? false;
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Pengguna',
                            value: '${users.length}',
                            icon: Icons.people_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            label: 'Online',
                            value: '$online',
                            icon: Icons.circle,
                            tint: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Diblokir',
                            value: '${banned.length}',
                            icon: Icons.block_outlined,
                            tint: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            label: 'Maintenance',
                            value: maintenanceOn ? 'ON' : 'OFF',
                            icon: Icons.handyman_outlined,
                            tint: maintenanceOn
                                ? Colors.amber
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _UpdateCard(accessEnabledCount: accessMap.values
                        .where((a) => a.enabled)
                        .length),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsLoading extends StatelessWidget {
  const _StatsLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _UpdateCard extends ConsumerWidget {
  const _UpdateCard({required this.accessEnabledCount});

  final int accessEnabledCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final version = config.valueOrNull?.update.versionName ?? '—';
    return SectionCard(
      title: 'Rilis & akses',
      subtitle: 'Versi terbaru yang diedarkan ke pengguna.',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'v$version',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  '$accessEnabledCount akun diizinkan',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.system_update_outlined),
        ],
      ),
    );
  }
}
