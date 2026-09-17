import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';

/// Status unduhan update APK (cermin onUpdateDownload* native).
enum UpdateDownloadStatus { idle, downloading, error }

/// Pengunduh APK update: simpan ke temp lalu buka installer sistem.
/// (cermin DownloadManager + UpdateDownloadReceiver native.)
class UpdateDownloader extends ChangeNotifier {
  UpdateDownloadStatus status = UpdateDownloadStatus.idle;
  String? errorMessage;

  /// Mengembalikan null bila sukses (installer dibuka), atau pesan error.
  Future<String?> downloadAndOpen(String apkUrl, String versionName) async {
    if (status == UpdateDownloadStatus.downloading) return null;
    status = UpdateDownloadStatus.downloading;
    errorMessage = null;
    notifyListeners();
    try {
      final safeVersion =
          versionName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final uri = Uri.tryParse(apkUrl);
      if (uri == null ||
          !(uri.scheme == 'https' || uri.scheme == 'http')) {
        throw StateError('Tautan APK update tidak valid.');
      }
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Unduhan gagal (HTTP ${response.statusCode}).');
      }
      final dir = Directory.systemTemp;
      final file = File(
        '${dir.path}/JadwalPintar-$safeVersion-'
        '${DateTime.now().millisecondsSinceEpoch}.apk',
      );
      await file.writeAsBytes(response.bodyBytes, flush: true);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        throw StateError('Tidak dapat membuka installer: ${result.message}');
      }
      status = UpdateDownloadStatus.idle;
      notifyListeners();
      return null;
    } catch (e) {
      status = UpdateDownloadStatus.error;
      errorMessage = '$e'.replaceFirst('Exception: ', '');
      notifyListeners();
      return errorMessage;
    }
  }

  void reset() {
    status = UpdateDownloadStatus.idle;
    errorMessage = null;
    notifyListeners();
  }
}
