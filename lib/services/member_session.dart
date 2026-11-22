import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Switch for the member login screen. true = Phone Number + OTP,
/// false = the old Member ID + password screen (kept in the project).
const bool kPhoneLoginEnabled = true;

/// Finds "who is signed in" for members. Members who sign in with a phone
/// number have a different Firebase user id than their member record, so the
/// record is found by the verified phone number instead of by uid.
class MemberSession {
  /// Member chosen at login when one phone number belongs to several records.
  static String? chosenMemberId;

  /// A phone login stays active for this many days.
  static const int sessionDays = 365;

  static final _db = FirebaseFirestore.instance;

  /// "98765 43210", "+91 98765 43210", "09876543210" -> "+919876543210".
  /// Returns null if it is not a valid Indian 10-digit mobile number.
  static String? toE164(String input) {
    var d = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
    if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
    if (d.length != 10) return null;
    return '+91$d';
  }

  static bool isPhoneUser(User? u) => (u?.phoneNumber ?? '').isNotEmpty;

  static bool isExpired(User u) {
    final last = u.metadata.lastSignInTime;
    return last != null && DateTime.now().difference(last).inDays > sessionDays;
  }

  /// Verified, active member records for a phone number.
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> membersForPhone(
      String e164) async {
    final snap =
        await _db.collection('members').where('phoneE164', isEqualTo: e164).get();
    return snap.docs.where(_usable).toList();
  }

  static bool _usable(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return m['phoneVerified'] == true && (m['isActive'] as bool? ?? true);
  }

  static DocumentSnapshot<Map<String, dynamic>>? _pick(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final usable = docs.where(_usable).toList();
    if (usable.isEmpty) return null;
    if (chosenMemberId != null) {
      for (final d in usable) {
        if (d.data()['memberId'] == chosenMemberId) return d;
      }
    }
    return usable.first;
  }

  /// The signed-in member's record (phone login or the old uid login).
  static Future<DocumentSnapshot<Map<String, dynamic>>?> currentDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    if (isPhoneUser(user)) {
      final snap = await _db
          .collection('members')
          .where('phoneE164', isEqualTo: user.phoneNumber)
          .get();
      return _pick(snap.docs);
    }
    return _db.collection('members').doc(user.uid).get();
  }

  /// Live version of [currentDoc].
  static Stream<DocumentSnapshot<Map<String, dynamic>>?> currentDocStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    if (isPhoneUser(user)) {
      return _db
          .collection('members')
          .where('phoneE164', isEqualTo: user.phoneNumber)
          .snapshots()
          .map((s) => _pick(s.docs));
    }
    return _db.collection('members').doc(user.uid).snapshots();
  }
}
