import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme.dart';
import '../user_theme_provider.dart';
import 'liquid_glass.dart';

/// Panel kaca iPhone untuk bottom sheet: blur latar + tint + border atas.
/// Aktif hanya saat preset Glass; preset lain mengembalikan konten as-is.
/// Dipakai bersama backgroundColor transparan di showModalBottomSheet.
/// Dioptimalkan: sinkron token liquid_glass + RepaintBoundary + sigma ringan.
class GlassPanel extends ConsumerWidget {
  const GlassPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(userThemeProvider);
    final glass = theme.preset == ThemePreset.glass;
    if (!glass) return child;
    return LiquidGlassPanel(isLight: theme.isLight, child: child);
  }
}
