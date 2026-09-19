import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Design-token Liquid Glass iPhone 26 — satu sumber kebenaran.
/// Tujuan: mirip kaca cair (blur + tint + specular + border hairline)
/// dengan cost minimal: blur hanya di lapisan latar, kartu hanya translusen.

/// Blur tunggal untuk seluruh layar (di belakang kartu, bukan per-kartu).
const double kGlassBlur = 14;
/// Blur untuk bottom sheet (lebih pekat karena sheet menutup konten).
const double kGlassBlurSheet = 20;
/// Blur untuk dialog tengah.
const double kGlassBlurDialog = 24;

/// Fill lensa: ~10-12% putih (dark), ~65% putih (light).
const Color kGlassFillDark = Color(0x1CFFFFFF); // 11% white
const Color kGlassFillLight = Color(0x9CFFFFFF); // ~61% white
/// Border hairline putih 30% (dark) / hitam 12% (light).
const Color kGlassBorderDark = Color(0x33FFFFFF);
const Color kGlassBorderLight = Color(0x1A000000);
/// Highlight specular atas (putih 18% → transparan).
const Color kGlassHighlight = Color(0x2EFFFFFF);
/// Tint scaffold gelap solid (bukan transparan ke hitam OS).
const Color kGlassScaffoldDark = Color(0xFF0A0E1A);
const Color kGlassScaffoldLight = Color(0xFFF4F6FB);
/// Glow radial (yang di-blur backdrop).
const Color kGlassGlowA = Color(0xFF007AFF);
const Color kGlassGlowB = Color(0xFF5856D6);
const Color kGlassGlowC = Color(0xFF8B5CF6);

/// Helper: apakah konteks sedang dalam mode glass + terang/gelap.
bool isGlass(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).scaffoldBackgroundColor == kGlassScaffoldDark
        : false;

/// Backdrop tunggal — letakkan sekali di Stack paling belakang.
/// Memburamkan glow di belakang kartu. Kartu di atasnya hanya translusen.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, this.sigma = kGlassBlur});

  final double sigma;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: const SizedBox.expand(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.transparent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Latar scaffold glass: gradient gelap/terang + 2 glow radial.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.isLight});

  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isLight
                ? const [Color(0xFFE8ECF5), Color(0xFFF7F8FD)]
                : const [Color(0xFF080B14), Color(0xFF0F1323)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -130,
              left: -110,
              child: _Glow(color: isLight ? kGlassGlowA.withValues(alpha: .14) : kGlassGlowA.withValues(alpha: .18)),
            ),
            Positioned(
              bottom: -150,
              right: -120,
              child: _Glow(color: isLight ? kGlassGlowB.withValues(alpha: .10) : kGlassGlowB.withValues(alpha: .16)),
            ),
            if (!isLight)
              Positioned(
                top: 380,
                right: -80,
                child: _Glow(color: kGlassGlowC.withValues(alpha: .10), size: 260),
              ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, this.size = 320});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Kartu kaca cair untuk konten scroll (tanpa BackdropFilter sendiri).
/// Efek kaca didapat dari GlassBackdrop di belakang.
class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.radius = 22,
    this.isLight = false,
    this.padding,
    this.onTap,
  });

  final Widget child;
  final double radius;
  final bool isLight;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fill = isLight ? kGlassFillLight : kGlassFillDark;
    final border = isLight ? kGlassBorderLight : kGlassBorderDark;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? .06 : .28),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 0.8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                kGlassHighlight.withValues(alpha: isLight ? .08 : .14),
                Colors.transparent,
                Colors.black.withValues(alpha: isLight ? .02 : .08),
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
          child: child,
        ),
      ),
    );
    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: content,
    );
    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: clipped),
      );
    }
    return clipped;
  }
}

/// Pill kaca untuk header/menu/countdown/badge.
class LiquidGlassPill extends StatelessWidget {
  const LiquidGlassPill({super.key, required this.child, this.isLight = false, this.radius = 999});

  final Widget child;
  final bool isLight;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(isLight: isLight, radius: radius, padding: null, child: child);
  }
}

/// Inset kaca untuk countdown.
class LiquidGlassInset extends StatelessWidget {
  const LiquidGlassInset({super.key, required this.child, this.isLight = false});

  final Widget child;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: (isLight ? Colors.white.withValues(alpha: .55) : Colors.white.withValues(alpha: .07)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLight ? const Color(0x14000000) : const Color(0x1AFFFFFF)),
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: isLight ? scheme.onSurface : Colors.white.withValues(alpha: .92), fontSize: 13),
        child: child,
      ),
    );
  }
}

/// Panel bottom sheet kaca (dengan blur sendiri, tapi ringan).
class LiquidGlassPanel extends StatelessWidget {
  const LiquidGlassPanel({super.key, required this.child, this.isLight = false});

  final Widget child;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(top: Radius.circular(28));
    final fill = isLight ? const Color(0xE8FFFFFF) : const Color(0xB81A1D2E);
    final border = isLight ? const Color(0x1A000000) : const Color(0x33FFFFFF);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: kGlassBlurSheet, sigmaY: kGlassBlurSheet),
        child: RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: radius,
              border: Border(top: BorderSide(color: border, width: 0.8)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: .22), blurRadius: 32, offset: const Offset(0, -8)),
              ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kGlassHighlight.withValues(alpha: isLight ? .10 : .18), Colors.transparent],
                  stops: const [0, 0.5],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog tengah kaca.
class LiquidGlassDialog extends StatelessWidget {
  const LiquidGlassDialog({super.key, required this.child, this.isLight = false});

  final Widget child;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    const radius = 24.0;
    final fill = isLight ? const Color(0xF0FFFFFF) : const Color(0xCC1A1D2E);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: kGlassBlurDialog, sigmaY: kGlassBlurDialog),
        child: RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: isLight ? const Color(0x1A000000) : const Color(0x33FFFFFF), width: 0.8),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: .28), blurRadius: 40, offset: const Offset(0, 16)),
              ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kGlassHighlight.withValues(alpha: isLight ? .12 : .22), Colors.transparent],
                  stops: const [0, 0.55],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Fullscreen overlay kaca (maintenance/update/lock) — tint + blur + card tengah.
class LiquidGlassFullscreen extends StatelessWidget {
  const LiquidGlassFullscreen({super.key, required this.child, this.isLight = false});

  final Widget child;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isLight ? Colors.white.withValues(alpha: .72) : const Color(0xFF0A0E1A).withValues(alpha: .88),
            ),
          ),
        ),
        const GlassBackdrop(sigma: 18),
        Center(child: child),
      ],
    );
  }
}

/// FAB kaca.
class LiquidGlassFab extends StatelessWidget {
  const LiquidGlassFab({super.key, required this.onPressed, required this.child, this.isLight = false});

  final VoidCallback onPressed;
  final Widget child;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: isLight ? Colors.white.withValues(alpha: .82) : scheme.primary.withValues(alpha: .88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isLight ? const Color(0x14000000) : Colors.white.withValues(alpha: .22)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(width: 56, height: 56, child: Center(child: child)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper untuk menampilkan dialog kaca konsisten.
Future<T?> showLiquidGlassDialog<T>({
  required BuildContext context,
  required Widget child,
  required bool isLight,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: isLight ? .18 : .42),
    builder: (ctx) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: LiquidGlassDialog(isLight: isLight, child: child),
        ),
      ),
    ),
  );
}

/// Helper bottom sheet kaca konsisten.
Future<T?> showLiquidGlassSheet<T>({
  required BuildContext context,
  required Widget child,
  required bool isLight,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: isLight ? .12 : .30),
    builder: (_) => LiquidGlassPanel(isLight: isLight, child: child),
  );
}
