import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../widgets.dart';

/// Halaman maintenance + proteksi level device.
class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  bool _enabled = false;
  bool _protection = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  void _syncFrom(AppConfig config) {
    if (_loaded) return;
    _loaded = true;
    _title.text = config.maintenance.title;
    _message.text = config.maintenance.message;
    _enabled = config.maintenance.enabled;
    _protection = config.protection.enabled;
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      final current = await ref.read(appConfigProvider.future);
      final map = <String, Object?>{
        'maintenance': MaintenanceConfig(
          enabled: _enabled,
          title: _title.text.trim(),
          message: _message.text.trim(),
        ).toMap(),
        'update': current.update.toMap(),
        'accessBlocked': current.popup.toMap(),
        'deviceProtection': DeviceProtectionConfig(
          enabled: _protection,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          updatedBy: user.uid,
        ).toMap(),
        'updatedAt': ServerValue.timestamp,
        'updatedBy': user.uid,
        'updatedByEmail': user.email ?? '',
      };
      await db.saveAppConfig(map);
      await db.writeAudit(
        adminUid: user.uid,
        adminEmail: user.email ?? '',
        action: 'save_app_config',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konfigurasi tersimpan')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance')),
      body: config.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: EmptyState(text: 'Gagal memuat: $e')),
        data: (value) {
          _syncFrom(value);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Mode maintenance',
                subtitle: 'Batasi akses pengguna selama perbaikan.',
                child: SwitchRow(
                  title: 'Aktifkan maintenance',
                  status: _enabled
                      ? 'Status: ON • Akses pengguna dibatasi'
                      : 'Status: OFF • Layanan normal',
                  statusOn: _enabled,
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Proteksi level device',
                subtitle:
                    'ON = perangkat banned terkunci total sejak boot. OFF = hanya ditolak login.',
                child: SwitchRow(
                  title: 'Kunci total perangkat banned',
                  status: _protection
                      ? 'Status: ON • Perangkat banned terkunci total'
                      : 'Status: OFF • Hanya ditolak login',
                  statusOn: _protection,
                  value: _protection,
                  onChanged: (v) => setState(() => _protection = v),
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Pesan maintenance',
                child: Column(
                  children: [
                    TextField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Judul maintenance',
                        hintText: 'Aplikasi sedang diperbaiki',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _message,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Isi maintenance',
                        hintText: 'Tuliskan informasi dan estimasi waktu.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Preview pengguna',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title.text.isEmpty
                          ? 'Aplikasi sedang diperbaiki'
                          : _title.text,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _message.text.isEmpty
                          ? 'Pesan maintenance akan tampil di sini.'
                          : _message.text,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Menyimpan…' : 'Simpan maintenance'),
              ),
            ],
          );
        },
      ),
    );
  }
}
