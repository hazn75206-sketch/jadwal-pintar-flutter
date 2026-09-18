import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme.dart';
import '../user_theme_provider.dart';

/// Panel kaca iPhone untuk bottom sheet: blur latar + tint + border atas.
/// Aktif hanya saat preset Glass; preset lain mengembalikan konten as-is.
/// Dipakai bersama backgroundColor transparan di showModalBottomSheet.
class GlassPanel extends ConsumerWidget {
  const GlassPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass =
        ref.watch(userThemeProvider).preset == ThemePreset.glass;
    if (!glass) return child;
    const radius =
        BorderRadius.vertical(top: Radius.circular(28));
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xB31C1C1E),
            borderRadius: radius,
            border: Border(
              top: BorderSide(color: Color(0x1FFFFFFF)),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
