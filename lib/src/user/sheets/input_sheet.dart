import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/sfx.dart';
import 'schedule_model.dart';
import 'schedule_provider.dart';

/// Modal input pelajaran (cermin #modal native): dropdown hari custom +
/// baris mapel dinamis (+ di baris terakhir, x di lainnya).
class InputSheet extends ConsumerStatefulWidget {
  const InputSheet({super.key, this.day, this.index});

  /// Hari awal (mode tambah). Null bila mode ubah.
  final String? day;

  /// Index pelajaran bila mode ubah.
  final int? index;

  bool get isEdit => day != null && index != null;

  @override
  ConsumerState<InputSheet> createState() => _InputSheetState();
}

class _InputSheetState extends ConsumerState<InputSheet> {
  late String _selectedDay;
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _selectedDay = widget.day!;
      final current =
          ref.read(scheduleProvider.select((s) => s.data));
      final list = current.days[widget.day!] ?? const <String>[];
      final initial = widget.index! >= 0 && widget.index! < list.length
          ? list[widget.index!]
          : '';
      _controllers = [TextEditingController(text: initial)];
    } else {
      _selectedDay = widget.day ?? kDays.first;
      _controllers = [TextEditingController()];
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final values = _controllers
        .map((c) => c.text.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    if (values.isEmpty) return;
    final controller = ref.read(scheduleProvider.notifier);
    if (widget.isEdit) {
      await controller.editLesson(
          widget.day!, widget.index!, values.first);
    } else {
      await controller.addLessons(_selectedDay, values);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(FontAwesomeIcons.bookOpen, size: 30),
              const SizedBox(height: 10),
              Text(
                widget.isEdit ? 'Ubah Pelajaran' : 'Pelajaran Baru',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              _DayDropdown(
                selected: _selectedDay,
                onChanged: (day) => setState(() => _selectedDay = day),
              ),
              const SizedBox(height: 12),
              ...List.generate(_controllers.length, (i) {
                final isLast = i == _controllers.length - 1;
                final showAction =
                    !widget.isEdit && _controllers.length >= 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controllers[i],
                          autofocus: i == 0,
                          decoration: const InputDecoration(
                            hintText: 'Nama pelajaran',
                          ),
                        ),
                      ),
                      if (showAction) ...[
                        const SizedBox(width: 8),
                        if (isLast)
                          IconButton.filled(
                            onPressed: () {
                              setState(() {
                                _controllers.add(TextEditingController());
                              });
                            },
                            icon: const FaIcon(
                              FontAwesomeIcons.plus,
                              size: 16,
                            ),
                          )
                        else
                          IconButton.filledTonal(
                            onPressed: () {
                              setState(() {
                                _controllers.removeAt(i).dispose();
                              });
                            },
                            icon: FaIcon(
                              FontAwesomeIcons.xmark,
                              size: 16,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Sfx.play('click');
                        _save();
                      },
                      child: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dropdown hari custom (cermin day-dropdown native).
class _DayDropdown extends StatelessWidget {
  const _DayDropdown({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final day in kDays)
                  ListTile(
                    leading:
                        const FaIcon(FontAwesomeIcons.calendarDays),
                    title: Text(day),
                    trailing: day == selected
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.of(sheetContext).pop(day),
                  ),
              ],
            ),
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          prefixIcon: FaIcon(FontAwesomeIcons.calendarDays),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(selected),
            const FaIcon(FontAwesomeIcons.chevronDown, size: 14),
          ],
        ),
      ),
    );
  }
}
