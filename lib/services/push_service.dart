import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'push_stub.dart' if (dart.library.js_interop) 'push_web.dart';

/// Registers this device for phone notifications. The token is saved in
/// fcmTokens/{token}; a Firebase function sends the notifications.
class PushService {
  /// Firebase console → Project settings → Cloud Messaging → Web Push
  /// certificates → "Key pair".
  static const String vapidKey = 'PASTE_VAPID_KEY_HERE';

  static Future<void> register(String role) async {
    if (vapidKey.startsWith('PASTE')) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await registerPushToken(vapidKey);
    if (token == null) return;
    try {
      await FirebaseFirestore.instance.collection('fcmTokens').doc(token).set({
        'token': token,
        'role': role,
        'uid': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
