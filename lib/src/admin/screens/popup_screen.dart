import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../widgets.dart';

/// Halaman template popup blokir akun.
class PopupScreen extends ConsumerStatefulWidget {
  const PopupScreen({super.key});

  @override
  ConsumerState<PopupScreen> createState() => _PopupScreenState();
}

class _PopupScreenState extends ConsumerState<PopupScreen> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  void _syncFrom(PopupConfig popup) {
    if (_loaded) return;
    _loaded = true;
    _title.text = popup.title;
    _message.text = popup.message;
  }

  void _template(String title, String message) {
    setState(() {
      _title.text = title;
      _message.text = message;
    });
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      final current = await ref.read(appConfigProvider.future);
      final map = <String, Object?>{
        'maintenance': current.maintenance.toMap(),
        'deviceProtection': current.protection.toMap(),
        'update': current.update.toMap(),
        'accessBlocked': PopupConfig(
          title: _title.text.trim(),
          message: _message.text.trim(),
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
        const SnackBar(content: Text('Popup tersimpan')),
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
      appBar: AppBar(title: const Text('Popup Blokir')),
      body: config.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: EmptyState(text: 'Gagal memuat: $e')),
        data: (value) {
          _syncFrom(value.popup);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Isi popup',
                child: Column(
                  children: [
                    TextField(
                      controller: _title,
                      maxLength: 60,
                      decoration: InputDecoration(
                        labelText: 'Judul popup',
                        counterText: '${_title.text.length} / 60',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _message,
                      maxLines: 4,
                      maxLength: 240,
                      decoration: InputDecoration(
                        labelText: 'Isi popup',
                        counterText: '${_message.text.length} / 240',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _template(
                              'Akses akun dinonaktifkan',
                              'Akses cloud untuk akun ini sementara dinonaktifkan. Hubungi administrator jika Anda memerlukan bantuan.',
                            ),
                            child: const Text('Template akses'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _template(
                              'Verifikasi keamanan diperlukan',
                              'Kami mendeteksi perubahan pada akun Anda. Hubungi administrator untuk memulihkan akses dengan aman.',
                            ),
                            child: const Text('Template verifikasi'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Live preview',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title.text.isEmpty
                          ? 'Akses akun dinonaktifkan'
                          : _title.text,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _message.text.isEmpty
                          ? 'Pesan popup akan tampil di sini.'
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
                label: Text(_saving ? 'Menyimpan…' : 'Simpan popup'),
              ),
            ],
          );
        },
      ),
    );
  }
}
