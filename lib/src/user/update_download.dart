import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Status unduhan update APK.
enum UpdateDownloadStatus {
  idle,
  downloading,

  /// Unduhan valid tapi versinya sama/lebih lama dari terpasang:
  /// tawarkan hapus versi lama dulu.
  needsUninstall,
  error,
}

/// Pengunduh APK update 100% dalam aplikasi (tanpa downloader lain):
/// streaming http langsung ke folder Download (atau folder privat app
/// bila izin storage ditolak), lalu inspeksi versi + tanda tangan
/// SEBELUM membuka installer sistem.
class UpdateDownloader extends ChangeNotifier {
  static const MethodChannel _channel =
      MethodChannel('jadwalpintar/update');

  UpdateDownloadStatus status = UpdateDownloadStatus.idle;

  /// 0..1 saat total diketahui, null bila tak tentu.
  double? progress;
  String? errorMessage;

  /// Path APK hasil unduhan (tetap ada di folder Download).
  String? downloadedPath;
  int installedCode = -1;
  int archiveCode = -1;

  /// Mengembalikan null bila sukses / butuh aksi lanjutan di UI
  /// (lihat [status]), atau pesan error Indonesia.
  Future<String?> downloadAndOpen(String apkUrl, String versionName) async {
    if (status == UpdateDownloadStatus.downloading) return null;
    status = UpdateDownloadStatus.downloading;
    progress = 0;
    errorMessage = null;
    downloadedPath = null;
    installedCode = -1;
    archiveCode = -1;
    notifyListeners();
    try {
      final uri = Uri.tryParse(apkUrl);
      if (uri == null ||
          !(uri.scheme == 'https' || uri.scheme == 'http')) {
        throw StateError('Tautan APK update tidak valid.');
      }
      final dir = await _downloadDir();
      final safeVersion =
          versionName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final file = File(
        '${dir.path}/JadwalPintar-$safeVersion-'
        '${DateTime.now().millisecondsSinceEpoch}.apk',
      );
      await _streamToFile(uri, file);
      final size = await file.length();
      if (size < 1024 * 1024) {
        // Kemungkinan halaman HTML/wall-login, bukan APK
        // (kasus URL console Firebase yang kepaste).
        try {
          await file.delete();
        } catch (_) {}
        throw StateError(
          'File yang diunduh bukan APK valid (hanya $size byte). '
          'Cek URL update di aplikasi admin.',
        );
      }
      downloadedPath = file.path;
      installedCode = await _invokeInt('getInstalledVersionCode');
      archiveCode = await _invokeInt(
        'getArchiveVersionCode',
        <String, Object>{'path': file.path},
      );
      if (archiveCode <= 0) {
        throw StateError(
          'File bukan APK Android valid. Cek URL update di admin.',
        );
      }
      final sameSig = await _invokeBool(
        'signaturesMatch',
        <String, Object>{'path': file.path},
      );
      if (!sameSig) {
        throw StateError(
          'Tanda tangan APK beda (bukan dari rilis resmi). '
          'Hapus aplikasi lama lalu pasang manual dari folder Download.',
        );
      }
      if (archiveCode > installedCode) {
        final opened = await _invokeBool(
          'installApk',
          <String, Object>{'path': file.path},
        );
        if (!opened) {
          throw StateError('Tidak dapat membuka installer sistem.');
        }
        status = UpdateDownloadStatus.idle;
        progress = null;
        notifyListeners();
        return null;
      }
      // Versi sama/lebih lama terpasang → tawarkan hapus versi lama.
      status = UpdateDownloadStatus.needsUninstall;
      notifyListeners();
      return null;
    } catch (e) {
      status = UpdateDownloadStatus.error;
      errorMessage = _clean(e);
      notifyListeners();
      return errorMessage;
    }
  }

  /// Minta sistem menghapus aplikasi ini (dialog konfirmasi OS).
  /// File APK tetap ada di folder Download untuk dipasang manual.
  Future<void> uninstallOld() async {
    try {
      await _channel.invokeMethod<bool>('uninstallSelf');
    } catch (_) {}
  }

  void reset() {
    status = UpdateDownloadStatus.idle;
    progress = null;
    errorMessage = null;
    notifyListeners();
  }

  /// Folder Download publik bila diizinkan, bila tidak folder privat app.
  /// Keduanya murni ditulis aplikasi ini (tanpa downloader lain).
  Future<Directory> _downloadDir() async {
    try {
      var granted =
          await _channel.invokeMethod<bool>('hasStoragePermission') ??
              false;
      if (!granted) {
        granted =
            await _channel.invokeMethod<bool>('requestStoragePermission') ??
                false;
      }
      if (granted) {
        final path = await _channel
            .invokeMethod<String>('getPublicDownloadsDir');
        if (path != null && path.isNotEmpty) {
          final dir = Directory(path);
          if (await dir.exists()) return dir;
        }
      }
    } catch (_) {}
    final fallback = await _channel
        .invokeMethod<String>('getAppDownloadsDir');
    final dir = Directory(
      fallback == null || fallback.isEmpty ? Directory.systemTemp.path : fallback,
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// Unduh streaming: hemat RAM (tidak menampung 21 MB sekaligus).
  Future<void> _streamToFile(Uri uri, File file) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Unduhan gagal (HTTP ${response.statusCode}).');
      }
      final total = response.contentLength ?? -1;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in response.stream) {
          received += chunk.length;
          sink.add(chunk);
          if (total > 0) {
            progress =
                (received / total).clamp(0.0, 1.0).toDouble();
            notifyListeners();
          }
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  Future<int> _invokeInt(String method,
      [Map<String, Object> args = const <String, Object>{}]) async {
    try {
      final value = await _channel.invokeMethod<int>(method, args);
      return value ?? -1;
    } catch (_) {
      return -1;
    }
  }

  Future<bool> _invokeBool(String method,
      [Map<String, Object> args = const <String, Object>{}]) async {
    try {
      return await _channel.invokeMethod<bool>(method, args) ?? false;
    } catch (_) {
      return false;
    }
  }

  String _clean(Object e) {
    return '$e'
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '')
        .replaceFirst('StateError: ', '');
  }
}
