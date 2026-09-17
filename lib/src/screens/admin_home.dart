import 'package:flutter/material.dart';

import '../app.dart';
import '../core/flavor.dart';

/// Layar sementara flavor admin (Fase 0: validasi pipeline).
/// Diganti redesign Material 3 pada Fase 2.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Jadwal Pintar')),
      body: const Center(
        child: FirebaseStatusCard(flavor: AppFlavor.admin),
      ),
    );
  }
}
