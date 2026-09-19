import 'dart:async';

import 'package:flutter/services.dart';

/// Auto-hide system bars setelah 5 detik, muncul lagi saat swipe,
/// lalu hilang lagi 5 detik — berlaku untuk SEMUA layar (Admin & User).
/// Port delay immersiveSticky ala request: "muncul dulu, lalu hilang setelah berapa detik".
class AutoHideBars {
  AutoHideBars._();

  static Timer? _t;

  static void init() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _schedule();
    SystemChrome.setSystemUIChangeCallback((systemOverlaysAreVisible) async {
      if (systemOverlaysAreVisible) _schedule();
    });
  }

  static void _schedule() {
    _t?.cancel();
    _t = Timer(const Duration(seconds: 5), () {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    });
  }

  static void dispose() {
    _t?.cancel();
    SystemChrome.setSystemUIChangeCallback(null);
  }
}
