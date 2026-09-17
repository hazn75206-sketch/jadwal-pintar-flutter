import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';

/// Status koneksi gabungan: jaringan perangkat + socket database.
/// Keduanya harus true agar dianggap online (dot hijau).
class ConnectivityService {
  ConnectivityService({
    Connectivity? connectivity,
    FirebaseDatabase? database,
  })  : _connectivity = connectivity ?? Connectivity(),
        _database = database ?? FirebaseDatabase.instance;

  final Connectivity _connectivity;
  final FirebaseDatabase _database;

  Stream<bool> get onlineStream {
    final controller = StreamController<bool>.broadcast();
    var netOk = true;
    var dbOk = false;
    var closed = false;

    void emit() {
      if (!closed) controller.add(netOk && dbOk);
    }

    StreamSubscription<List<ConnectivityResult>>? netSub;
    StreamSubscription<DatabaseEvent>? dbSub;

    controller.onListen = () async {
      try {
        netOk = _hasNet(await _connectivity.checkConnectivity());
      } catch (_) {
        netOk = false;
      }
      emit();
      netSub = _connectivity.onConnectivityChanged.listen((results) {
        netOk = _hasNet(results);
        emit();
      });
      dbSub = _database.ref('.info/connected').onValue.listen((event) {
        dbOk = event.snapshot.value as bool? ?? false;
        emit();
      });
    };
    controller.onCancel = () async {
      closed = true;
      await netSub?.cancel();
      await dbSub?.cancel();
    };
    return controller.stream;
  }

  static bool _hasNet(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
