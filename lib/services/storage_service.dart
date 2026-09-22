import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Evidence files live under evidence/<complaintId>/. Only the storage PATH is saved in Firestore
/// (never a public link); files are read back through Storage security rules.
class StorageService {
  static Future<String> upload(Uint8List bytes, String ext, String contentType, int complaintId) async {
    final name = '${DateTime.now().microsecondsSinceEpoch}.$ext';
    final ref = FirebaseStorage.instance.ref('evidence/$complaintId/$name');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.fullPath;
  }

  static Future<Uint8List?> bytes(String path) =>
      FirebaseStorage.instance.ref(path).getData(10 * 1024 * 1024);

  static Future<String> downloadUrl(String path) => FirebaseStorage.instance.ref(path).getDownloadURL();
}
