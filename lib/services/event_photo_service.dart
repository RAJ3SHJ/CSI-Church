import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Photos for an event / upcoming event / announcement. They live in Firebase
/// Storage and the list is kept in the event document as
/// photos: [{url, path}].
class EventPhotoService {
  static List<Map<String, dynamic>> photosOf(Map<String, dynamic> data) {
    final raw = data['photos'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .where((m) => (m['url'] ?? '').toString().isNotEmpty)
        .toList();
  }

  /// Lets the admin pick one or many photos, compresses them in the picker
  /// and uploads them. Returns how many were uploaded.
  static Future<int> pickAndUpload(
    DocumentReference<Map<String, dynamic>> eventRef, {
    void Function(int done, int total)? onProgress,
  }) async {
    final files = await ImagePicker()
        .pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 78);
    if (files.isEmpty) return 0;
    var done = 0;
    for (final f in files) {
      final bytes = await f.readAsBytes();
      final path =
          'events/${eventRef.parent.id}_${eventRef.id}/${DateTime.now().microsecondsSinceEpoch}_$done.jpg';
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await eventRef.update({
        'photos': FieldValue.arrayUnion([
          {'url': url, 'path': path}
        ])
      });
      done++;
      onProgress?.call(done, files.length);
    }
    return done;
  }

  static Future<void> remove(
      DocumentReference<Map<String, dynamic>> eventRef, Map<String, dynamic> photo) async {
    try {
      await FirebaseStorage.instance.ref((photo['path'] ?? '').toString()).delete();
    } catch (_) {}
    await eventRef.update({
      'photos': FieldValue.arrayRemove([photo])
    });
  }
}
