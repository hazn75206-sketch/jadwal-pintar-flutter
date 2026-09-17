import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Modal info aplikasi (cermin #infoModal).
class InfoSheet extends StatelessWidget {
  const InfoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(FontAwesomeIcons.code, size: 30),
            const SizedBox(height: 10),
            Text(
              'Han Dev',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const _InfoRow(
                icon: FontAwesomeIcons.user, text: 'Developer: Han Dev'),
            const _InfoRow(
                icon: FontAwesomeIcons.box,
                text: 'Package: com.jadwalpintar.app'),
            const _InfoRow(
                icon: FontAwesomeIcons.tag, text: 'Versi 3.0 - Flutter Edition'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Selesai'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal privasi (cermin #privacyModal).
class PrivacySheet extends StatelessWidget {
  const PrivacySheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(FontAwesomeIcons.shieldHalved, size: 30),
            const SizedBox(height: 10),
            Text(
              'Privasi',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const _InfoRow(
                icon: FontAwesomeIcons.mobileScreen,
                text: 'Data jadwal tersimpan di perangkat Anda'),
            const _InfoRow(
                icon: FontAwesomeIcons.google,
                text: 'Cadangan hanya di akun Google Anda sendiri'),
            const _InfoRow(
                icon: FontAwesomeIcons.userShield,
                text: 'Tidak dibagikan ke pihak ketiga mana pun'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          FaIcon(icon, size: 15),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
