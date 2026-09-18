import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session.dart';
import 'home_screen.dart';
import 'splash_screen.dart';

/// Entrypoint UI flavor user: splash saat boot, lalu layar jadwal + gate.
/// Splash ditahan minimal 1,2 detik agar tidak kedip.
class UserHomeScreen extends ConsumerStatefulWidget {
  const UserHomeScreen({super.key});

  @override
  ConsumerState<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends ConsumerState<UserHomeScreen> {
  static const _minSplash = Duration(milliseconds: 1200);

  final DateTime _start = DateTime.now();
  bool _revealed = false;

  void _maybeReveal(SessionStatus status) {
    if (_revealed || status == SessionStatus.boot) return;
    final elapsed = DateTime.now().difference(_start);
    if (elapsed >= _minSplash) {
      _revealed = true;
      return;
    }
    Future.delayed(_minSplash - elapsed, () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // SessionController boot sendiri saat pertama di-watch.
    final session = ref.watch(sessionProvider);
    _maybeReveal(session.status);
    if (!_revealed) return const SplashScreen();
    return const HomeScreen();
  }
}
