import 'package:flutter/material.dart';

import '../app.dart';
import '../core/flavor.dart';

/// Layar sementara flavor user (Fase 0: validasi pipeline).
/// Diganti faithful-port UI jadwal pada Fase 3.
class UserHomeScreen extends StatelessWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal Pintar')),
      body: const Center(
        child: FirebaseStatusCard(flavor: AppFlavor.user),
      ),
    );
  }
}
