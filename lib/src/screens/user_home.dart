import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session.dart';
import 'screens/home_screen.dart';

/// Entrypoint UI flavor user — layar jadwal + gate sesi.
class UserHomeScreen extends ConsumerWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // SessionController boot sendiri saat pertama di-watch.
    ref.watch(sessionProvider);
    return const HomeScreen();
  }
}
