import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/sfx.dart';
import '../schedule_model.dart';
import '../schedule_provider.dart';

/// Modal manajemen data (cermin #dataModal): jam masuk, ekspor, impor.
class DataSheet extends ConsumerStatefulWidget {
  const DataSheet({super.key});

  @override
  ConsumerState<DataSheet> createState() => _DataSheetState();
}

class _DataSheetState extends ConsumerState<DataSheet> {
  late final TextEditingController _fileName;

  @override
  void initState() {
    super.initState();
    _fileName = TextEditingController(text: 'Jadwal_Sekolah');
  }

  @override
  void dispose() {
    _fileName.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final current = ref.read(scheduleProvider).startTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(current.isNotEmpty ? current[0] : '') ?? 7,
      minute: int.tryParse(current.length > 1 ? current[1] : '') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await ref.read(scheduleProvider.notifier).setStartTime(value);
    await Sfx.play('success');
  }

  Future<void> _export() async {
    final name = _fileName.text.trim().isEmpty
        ? 'Jadwal'
        : _fileName.text.trim();
    final json = ref.read(scheduleProvider).data.toJsonString();
    final pretty = const JsonEncoder.withIndent('  ').convert(
      ScheduleData.fromJsonString(json).days,
    );
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Simpan jadwal',
      fileName: '$name.json',
      mimeType: 'application/json',
      bytes: Uint8List.fromList(utf8.encode(pretty)),
    );
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ekspor dibatalkan')),
      );
      return;
    }
    await Sfx.play('success');
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File jadwal tersimpan')),
    );
  }

  Future<void> _import() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt'],
    );
    if (files.isEmpty) return;
    String? raw;
    try {
      raw = utf8.decode(await files.first.readAsBytes());
    } catch (_) {
      raw = null;
    }
    if (raw == null) {
      await Sfx.play('error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File tidak valid!')),
      );
      return;
    }
    final error =
        await ref.read(scheduleProvider.notifier).importJson(raw);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil memuat data!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final startTime = ref.watch(
      scheduleProvider.select((s) => s.startTime),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Manajemen Data',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Ekspor atau Impor jadwal Anda dengan mudah.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text(
                'Jam Masuk Sekolah (untuk pengingat)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickStartTime,
                icon: const FaIcon(FontAwesomeIcons.bell, size: 16),
                label: Text(startTime),
              ),
              const SizedBox(height: 16),
              Text(
                'Nama File Ekspor',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _fileName,
                decoration: const InputDecoration(
                  suffixText: '.json',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _export,
                icon: const FaIcon(FontAwesomeIcons.download, size: 16),
                label: const Text('Simpan ke Perangkat'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _import,
                icon: const FaIcon(FontAwesomeIcons.upload, size: 16),
                label: const Text('Muat File Jadwal'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
