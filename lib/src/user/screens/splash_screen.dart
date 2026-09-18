import 'package:flutter/material.dart';

/// Splash screen app user: ikon aplikasi di tengah, nama aplikasi di
/// bawahnya, animasi loading ala chat (titik memantul) di tengah-bawah.
/// Menggantikan spinner boot polos + menutup jeda hitam saat dibuka.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF080A12),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AppIcon(),
                  SizedBox(height: 18),
                  Text(
                    'Jadwal Pintar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 72,
              child: Center(child: TypingDots()),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40007AFF),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.asset(
          'assets/icon/app_icon.png',
          width: 112,
          height: 112,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(
            color: Color(0xFF007AFF),
            child: Icon(
              Icons.calendar_month,
              size: 56,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiga titik memantul berurutan ala indikator "mengetik" di chat.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) _dot(i),
          ],
        );
      },
    );
  }

  Widget _dot(int index) {
    // Gelombang 0→1→0 per titik, digeser 0.2 fase tiap titik.
    final t = (_controller.value + index * 0.2) % 1.0;
    final bounce = t < 0.5 ? t * 2 : (1 - t) * 2;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: Transform.translate(
        offset: Offset(0, -8 * bounce),
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(
              alpha: 0.35 + 0.65 * bounce,
            ),
          ),
        ),
      ),
    );
  }
}
