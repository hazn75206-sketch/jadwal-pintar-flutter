import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../theme.dart';
import '../user_theme_provider.dart';

/// Modal pilih tema (cermin #themeModal): 8 preset + custom + terang.
class ThemeSheet extends ConsumerWidget {
  const ThemeSheet({super.key});

  Future<void> _pickCustom(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: '#007AFF');
    final hex = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Warna custom (hex)'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '#007AFF',
            prefixIcon: FaIcon(FontAwesomeIcons.palette),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Pakai'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (hex == null || hex.isEmpty) return;
    final clean = hex.replaceAll('#', '').trim();
    final value = int.tryParse('FF$clean', radix: 16);
    if (value == null || clean.length != 6) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Format hex tidak valid')),
        );
      }
      return;
    }
    await ref
        .read(userThemeProvider.notifier)
        .setCustomColor(Color(value));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(userThemeProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pilih Tema',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'Sesuaikan warna tampilan aplikasi',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  for (final preset in ThemePreset.values)
                    _ThemeOption(
                      label: presetLabels[preset] ?? preset.name,
                      selected: theme.preset == preset,
                      dot: preset == ThemePreset.custom
                          ? null
                          : _dotColor(preset, theme.customColor),
                      isCustom: preset == ThemePreset.custom,
                      onTap: () {
                        if (preset == ThemePreset.custom) {
                          _pickCustom(context, ref);
                        } else {
                          ref
                              .read(userThemeProvider.notifier)
                              .setPreset(preset);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Mode terang'),
                value: theme.isLight,
                onChanged: (value) => ref
                    .read(userThemeProvider.notifier)
                    .setLight(value),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Selesai'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _dotColor(ThemePreset preset, Color custom) {
    switch (preset) {
      case ThemePreset.blue:
        return const Color(0xFF007AFF);
      case ThemePreset.emerald:
        return const Color(0xFF10B981);
      case ThemePreset.purple:
        return const Color(0xFF8B5CF6);
      case ThemePreset.ruby:
        return const Color(0xFFEF4444);
      case ThemePreset.amber:
        return const Color(0xFFF59E0B);
      case ThemePreset.sky:
        return const Color(0xFF0EA5E9);
      case ThemePreset.pink:
        return const Color(0xFFEC4899);
      case ThemePreset.glass:
        return const Color(0xFF8B5CF6);
      case ThemePreset.custom:
        return custom;
    }
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
    this.isCustom = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;
  final bool isCustom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCustom ? null : dot,
                border: isCustom
                    ? Border.all(color: scheme.outline)
                    : null,
              ),
              child: isCustom
                  ? const FaIcon(FontAwesomeIcons.palette, size: 14)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
