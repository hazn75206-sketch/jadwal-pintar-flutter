import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Upload APK rilis ke Firebase Storage (dipakai app admin).
class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Mengunggah [file] ke `updates/` + [objectName] pada [bucket] dan
  /// mengembalikan download URL. [onProgress] menerima 0.0–1.0 (null bila
  /// ukuran total tak diketahui).
  Future<String> uploadApk({
    required String bucket,
    required String objectName,
    required File file,
    required void Function(double? progress) onProgress,
  }) async {
    final normalizedBucket =
        bucket.startsWith('gs://') ? bucket : 'gs://$bucket';
    final ref = FirebaseStorage.instanceFor(bucket: normalizedBucket)
        .ref(objectName);
    final task = ref.putFile(file);
    final subscription = task.snapshotEvents.listen((snapshot) {
      final total = snapshot.totalBytes;
      if (total > 0) {
        onProgress(snapshot.bytesTransferred / total);
      } else {
        onProgress(null);
      }
    });
    try {
      await task;
      return await ref.getDownloadURL();
    } finally {
      await subscription.cancel();
    }
  }

  FirebaseStorage get storage => _storage;
}
