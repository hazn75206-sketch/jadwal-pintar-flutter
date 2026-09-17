import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../widgets.dart';

/// Batas bawah versionCode update (versi aplikasi yang dikontrol).
const int kControlledAppVersionCode = 2;

/// Halaman update APK: version, upload Storage, paksa update.
class UpdateScreen extends ConsumerStatefulWidget {
  const UpdateScreen({super.key});

  @override
  ConsumerState<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends ConsumerState<UpdateScreen> {
  final _code = TextEditingController(text: '3');
  final _name = TextEditingController(text: '3.0.0');
  final _apkUrl = TextEditingController();
  final _bucket =
      TextEditingController(text: 'jadwal-pintar.firebasestorage.app');
  final _title = TextEditingController(text: 'Update tersedia');
  final _message = TextEditingController(
      text: 'Silakan perbarui aplikasi ke versi terbaru.');
  bool _enabled = false;
  bool _force = false;
  bool _loaded = false;
  bool _saving = false;
  bool _uploading = false;
  double? _progress;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _apkUrl.dispose();
    _bucket.dispose();
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  void _syncFrom(UpdateConfig update) {
    if (_loaded) return;
    _loaded = true;
    _enabled = update.enabled;
    _force = update.force;
    _code.text = '${update.versionCode}';
    _name.text = update.versionName;
    _apkUrl.text = update.apkUrl;
    if (update.storageBucket.isNotEmpty) _bucket.text = update.storageBucket;
    _title.text = update.title;
    _message.text = update.message;
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePickerPlatform.instance.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _uploading = true;
      _progress = 0;
    });
    try {
      final url = await ref.read(storageServiceProvider).uploadApk(
            bucket: _bucket.text.trim(),
            objectName:
                'updates/jadwal-pintar-${DateTime.now().millisecondsSinceEpoch}.apk',
            file: File(path),
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
          );
      _apkUrl.text = url;
      setState(() => _enabled = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload APK selesai')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload APK gagal: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final versionCode = int.tryParse(_code.text.trim());
    if (versionCode == null || versionCode < 1) {
      _snack('Version code harus berupa angka minimal 1.', true);
      return;
    }
    if (_enabled && versionCode <= kControlledAppVersionCode) {
      _snack(
        'Version code update harus lebih besar dari versi saat ini '
        '($kControlledAppVersionCode).',
        true,
      );
      return;
    }
    if (_enabled && _apkUrl.text.trim().isEmpty) {
      _snack('URL APK wajib diisi ketika update diaktifkan.', true);
      return;
    }
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      final current = await ref.read(appConfigProvider.future);
      final map = <String, Object?>{
        'maintenance': current.maintenance.toMap(),
        'deviceProtection': current.protection.toMap(),
        'update': UpdateConfig(
          enabled: _enabled,
          force: _force,
          versionCode: versionCode,
          versionName: _name.text.trim(),
          apkUrl: _apkUrl.text.trim(),
          storageBucket: _bucket.text.trim(),
          title: _title.text.trim(),
          message: _message.text.trim(),
        ).toMap(),
        'accessBlocked': current.popup.toMap(),
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
      _snack('Konfigurasi tersimpan', false);
    } catch (e) {
      _snack('Gagal menyimpan: $e', true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message, bool error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Update APK')),
      body: config.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: EmptyState(text: 'Gagal memuat: $e')),
        data: (value) {
          _syncFrom(value.update);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Status rilis',
                child: Column(
                  children: [
                    SwitchRow(
                      title: 'Aktifkan update',
                      status: _enabled ? 'ON' : 'OFF',
                      statusOn: _enabled,
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                    SwitchRow(
                      title: 'Update wajib',
                      status: _force ? 'ON' : 'OFF',
                      statusOn: _force,
                      value: _force,
                      onChanged: (v) => setState(() => _force = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Versi & berkas',
                child: Column(
                  children: [
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Version code',
                        hintText: 'Contoh: 4',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Latest version',
                        hintText: 'Contoh: 3.0.0',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _bucket,
                      decoration: const InputDecoration(
                        labelText: 'Firebase bucket',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _apkUrl,
                      readOnly: true,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'URL APK (dari upload)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_uploading)
                      LinearProgressIndicator(
                        value: _progress,
                      ),
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickAndUpload,
                      icon: const Icon(Icons.upload_outlined),
                      label: Text(
                          _uploading ? 'Mengunggah…' : 'Upload APK'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Pesan update',
                child: Column(
                  children: [
                    TextField(
                      controller: _title,
                      decoration: const InputDecoration(labelText: 'Judul'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _message,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Pesan'),
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
                label: Text(_saving ? 'Menyimpan…' : 'Simpan update'),
              ),
            ],
          );
        },
      ),
    );
  }
}
