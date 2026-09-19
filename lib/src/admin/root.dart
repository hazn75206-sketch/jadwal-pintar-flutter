import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import 'shell.dart';

/// Gerbang auth admin: login Google → verifikasi node admins → shell.
/// Menolak dengan UID terlihat bila bukan admin terdaftar.
class AdminRoot extends ConsumerWidget {
  const AdminRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => LoginScreen(message: 'Gagal memuat sesi: $error'),
      data: (user) {
        if (user == null) return const LoginScreen();
        return _AdminVerifier(uid: user.uid);
      },
    );
  }
}

class _AdminVerifier extends ConsumerWidget {
  const _AdminVerifier({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<bool>(
      future: ref.watch(databaseProvider).isAdmin(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) return const AdminShell();
        return _AccessDenied(uid: uid);
      },
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.message = 'Masuk menggunakan akun administrator.'});

  final String message;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // SaaS mint-green login — keep Google auth logic 1:1, only visuals changed.
    const bgOffWhite = Color(0xFFF3F8F3);
    const bgMintEnd = Color(0xFFEAF3EC);
    const primaryGreen = Color(0xFF0F7A4A);
    const charcoal = Color(0xFF1E2E2B);
    const muted = Color(0xFF6B7F7C);

    return Scaffold(
      backgroundColor: bgOffWhite,
      body: Stack(
        children: [
          // Soft gradient base.
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF7FCF7), bgMintEnd],
                ),
              ),
            ),
          ),
          // Abstract decorations — low contrast, non-distracting.
          const _BackgroundDecorations(),
          // Main content centered, scrollable for small screens.
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                      minWidth: constraints.maxWidth - 40,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            // Icon — pale green circle with glow.
                            const _AdminIcon(),
                            const SizedBox(height: 22),
                            // Title.
                            RichText(
                              textAlign: TextAlign.center,
                              text: const TextSpan(
                                style: TextStyle(
                                  fontFamily: 'sans-serif',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                ),
                                children: [
                                  TextSpan(text: 'Admin ', style: TextStyle(color: charcoal)),
                                  TextSpan(text: 'Jadwal Pintar', style: TextStyle(color: primaryGreen)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Subtitle.
                            const Text(
                              'Kelola jadwal dengan mudah\ndan lebih teratur.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'sans-serif',
                                fontSize: 16,
                                height: 1.45,
                                fontWeight: FontWeight.w400,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 28),
                            // White floating card.
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F7A4A).withValues(alpha: 0.08),
                                    blurRadius: 32,
                                    offset: const Offset(0, 16),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Google button — 52-56dp, pill 28dp, green.
                                  _GoogleButton(busy: _busy, onPressed: _busy ? null : _login),
                                  const SizedBox(height: 16),
                                  // Security note.
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE6F4EA),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(Icons.lock, size: 11, color: primaryGreen),
                                      ),
                                      const SizedBox(width: 7),
                                      const Text(
                                        'Login aman menggunakan Google',
                                        style: TextStyle(
                                          fontFamily: 'sans-serif',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF7A8E8A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Error / message.
                                  if (_error != null) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF0F0),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFFFD1D1)),
                                      ),
                                      child: Text(
                                        _error!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12.5, color: Color(0xFFB42318), height: 1.4),
                                      ),
                                    ),
                                  ] else if (widget.message != 'Masuk menggunakan akun administrator.' && widget.message.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF3E0),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFFFE0B2)),
                                      ),
                                      child: Text(
                                        widget.message,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF7A4A0B), height: 1.4),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Tiny version hint.
                            const Text(
                              '© Jadwal Pintar • Admin Console',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: Color(0xFF9DB0A8), letterSpacing: 0.3),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminIcon extends StatelessWidget {
  const _AdminIcon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 118,
        height: 118,
        decoration: BoxDecoration(
          color: const Color(0xFFE3F3E8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F7A4A).withValues(alpha: 0.12),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Shield.
                Positioned.fill(
                  child: Icon(
                    Icons.shield_outlined,
                    size: 64,
                    color: const Color(0xFF0F7A4A),
                    shadows: [
                      Shadow(color: const Color(0xFF0F7A4A).withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 6)),
                    ],
                  ),
                ),
                // Slight fill for depth.
                Positioned.fill(
                  child: Icon(
                    Icons.shield,
                    size: 64,
                    color: const Color(0xFF0F7A4A).withValues(alpha: 0.10),
                  ),
                ),
                // User badge bottom-right.
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0F7A4A), width: 2.2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.person, size: 20, color: Color(0xFF0F7A4A)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0F7A4A);
    const primaryDeep = Color(0xFF0B5C38);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A9A61), primaryDeep],
        ),
        boxShadow: [
          BoxShadow(color: primary.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          splashColor: Colors.white.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.06),
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  // G logo on white circle.
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Center(
                      child: _GoogleG(size: 20),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 26,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: Colors.white.withValues(alpha: 0.32),
                  ),
                  Expanded(
                    child: Center(
                      child: busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                          : const Text(
                              'Masuk dengan Google',
                              style: TextStyle(
                                fontFamily: 'sans-serif',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.1,
                              ),
                            ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(Icons.arrow_forward, size: 20, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal Google "G" — 4-color approximation without external asset.
class _GoogleG extends StatelessWidget {
  const _GoogleG({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    // Use stack of colored arcs approximation with FontAwesome colors fallback:
    // Simpler: use Row of letters with distinct colors? Instead draw single G with gradient.
    // Here we use a centered bold G with Google blue + colored dots simulation via shadow.
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          'G',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            height: 1,
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFFBBC05), Color(0xFFEA4335)],
              ).createShader(Rect.fromLTWH(0, 0, 24, 24)),
          ),
        ),
      ],
    );
  }
}

class _BackgroundDecorations extends StatelessWidget {
  const _BackgroundDecorations();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top organic blob - mint.
        Positioned(
          top: -70,
          left: -90,
          child: IgnorePointer(
            child: Container(
              width: 260,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFB9DCC5).withValues(alpha: 0.55),
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.elliptical(180, 120),
                  topLeft: Radius.circular(80),
                ),
              ),
            ),
          ),
        ),
        // Top curved outline.
        Positioned(
          top: -20,
          left: -30,
          child: IgnorePointer(
            child: Container(
              width: 300,
              height: 210,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(bottomRight: Radius.elliptical(200, 140)),
                border: Border.all(color: const Color(0xFF8CC0A0).withValues(alpha: 0.55), width: 1.4),
              ),
            ),
          ),
        ),
        // Dotted pattern top-right.
        const Positioned(top: 36, right: 18, child: _DotGrid()),
        // Bottom large wave.
        Positioned(
          bottom: -70,
          right: -60,
          child: IgnorePointer(
            child: Container(
              width: 360,
              height: 240,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFD6EBDC), Color(0xFF8FC5A0)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.elliptical(220, 160),
                  bottomRight: Radius.circular(60),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -30,
          right: -20,
          left: 40,
          child: IgnorePointer(
            child: Container(
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: const BorderRadius.only(topLeft: Radius.elliptical(320, 180)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1),
              ),
            ),
          ),
        ),
        // Bottom small blob left.
        Positioned(
          bottom: 90,
          left: -30,
          child: IgnorePointer(
            child: Container(
              width: 120,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F3E8).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(60),
              ),
            ),
          ),
        ),
        // Bottom dotted.
        const Positioned(bottom: 24, left: 18, child: _DotGrid(cols: 6, rows: 3)),
      ],
    );
  }
}

class _DotGrid extends StatelessWidget {
  const _DotGrid({this.cols = 5, this.rows = 3});
  final int cols;
  final int rows;

  @override
  Widget build(BuildContext context) {
    const dotColor = Color(0xFFB6D8C1);
    return IgnorePointer(
      child: Column(
        children: List.generate(rows, (r) {
          return Padding(
            padding: EdgeInsets.only(top: r == 0 ? 0 : 8),
            child: Row(
              children: List.generate(cols, (c) {
                return Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.only(left: c == 0 ? 0 : 9),
                  decoration: BoxDecoration(color: dotColor.withValues(alpha: 0.85), shape: BoxShape.circle),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}

class _AccessDenied extends ConsumerWidget {
  const _AccessDenied({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep same functionality, but match mint SaaS card style for consistency.
    const primary = Color(0xFF0F7A4A);
    const bg = Color(0xFFF3F8F3);
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const _BackgroundDecorations(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(color: primary.withValues(alpha: 0.08), blurRadius: 32, offset: const Offset(0, 16)),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4E6),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: const Icon(Icons.block_outlined, size: 32, color: Color(0xFFDC2626)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Bukan admin terdaftar',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF1E2E2B)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Akun ini tidak memiliki akses administrator.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Color(0xFF6B7F7C)),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6FBF7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE3F3E8)),
                          ),
                          child: SelectableText('UID: $uid', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF4A5A57), fontFamily: 'monospace')),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            onPressed: () => ref.read(authServiceProvider).signOut(),
                            child: const Text('Keluar & ganti akun', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
