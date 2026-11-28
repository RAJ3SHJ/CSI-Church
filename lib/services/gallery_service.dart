import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Church photo gallery. One Firestore doc per photo in `gallery`:
/// {category, url, path, createdAt}. Files live in Storage under gallery/.
class GalleryService {
  static const categories = <String, String>{
    'youth': 'Youth\nFellowship',
    'women': 'Women\'s\nFellowship',
    'sunday': 'Sunday\nSchool',
    'church': 'Church',
  };

  static String labelOf(String key) =>
      key == 'all' ? 'All' : (categories[key] ?? key).replaceAll('\n', ' ');

  static CollectionReference<Map<String, dynamic>> get col =>
      FirebaseFirestore.instance.collection('gallery');

  static List<Map<String, dynamic>> parse(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    list.sort((a, b) {
      final ta = a['createdAt'] as Timestamp?;
      final tb = b['createdAt'] as Timestamp?;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return list;
  }

  static List<Map<String, dynamic>> inCategory(List<Map<String, dynamic>> all, String key) =>
      key == 'all' ? all : all.where((p) => p['category'] == key).toList();

  static Future<int> pickAndUpload(String category,
      {void Function(int done, int total)? onProgress}) async {
    final files = await ImagePicker()
        .pickMultiImage(maxWidth: 1800, maxHeight: 1800, imageQuality: 80);
    if (files.isEmpty) return 0;
    var done = 0;
    for (final f in files) {
      final bytes = await f.readAsBytes();
      final path = 'gallery/$category/${DateTime.now().microsecondsSinceEpoch}_$done.jpg';
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await col.add({
        'category': category,
        'url': url,
        'path': path,
        'createdAt': FieldValue.serverTimestamp(),
      });
      done++;
      onProgress?.call(done, files.length);
    }
    return done;
  }

  static Future<void> remove(Map<String, dynamic> photo) async {
    try {
      await FirebaseStorage.instance.ref((photo['path'] ?? '').toString()).delete();
    } catch (_) {}
    await col.doc(photo['id'].toString()).delete();
  }
}
