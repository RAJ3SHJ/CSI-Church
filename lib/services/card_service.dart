import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Helpers for Monthly Subscription cards (financial year Apr–Mar).
/// A member can have several cards in a year (father, mother, wife, ...),
/// each with a name, a front photo and an optional back photo.
class CardService {
  /// Financial year start (e.g. 2026 for Apr 2026 – Mar 2027) of a date.
  static int fyStartOf(DateTime d) => d.month >= 4 ? d.year : d.year - 1;

  static int currentFyStart() => fyStartOf(DateTime.now());

  /// Cards can only be added or changed in the current or a future year.
  static bool isOpen(int fyStart) => fyStart >= currentFyStart();

  /// "2026-27"
  static String fyName(int start) =>
      '$start-${((start + 1) % 100).toString().padLeft(2, '0')}';

  /// "FY 2026-27"
  static String fyLabel(int start) => 'FY ${fyName(start)}';

  /// Parses "FY 2026-27" back to 2026 (null if not an FY label).
  static int? parseFyLabel(String label) {
    if (!label.startsWith('FY ')) return null;
    return int.tryParse(label.substring(3, 7));
  }

  static String slug(String name) {
    final s = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final t = s.replaceAll(RegExp(r'^-+|-+$'), '');
    if (t.isEmpty) return 'card';
    return t.length > 24 ? t.substring(0, 24) : t;
  }

  /// One card per name per member per financial year; same id = replace.
  static String docId(String memberId, int fyStart, String cardName) =>
      '${memberId}_${fyStart}_${slug(cardName)}';

  /// Name to show for a stored card (older cards had no name).
  static String displayName(Map<String, dynamic> m) {
    final n = (m['cardName'] ?? '').toString().trim();
    if (n.isNotEmpty) return n;
    final mn = (m['memberName'] ?? '').toString().trim();
    return mn.isNotEmpty ? mn : 'Card';
  }

  /// True if a card with this name already exists for the member and year.
  static Future<bool> exists(String memberId, int fyStart, String cardName) async {
    final d = await FirebaseFirestore.instance
        .collection('membercards')
        .doc(docId(memberId, fyStart, cardName))
        .get();
    return d.exists;
  }

  /// Saves (or replaces) a card. Past financial years are closed.
  static Future<void> save({
    required String memberId,
    required String memberName,
    required int fyStart,
    required String cardName,
    required Uint8List front,
    Uint8List? back,
  }) {
    if (!isOpen(fyStart)) {
      throw StateError('${fyLabel(fyStart)} is closed. Cards can no longer be added or changed.');
    }
    return FirebaseFirestore.instance
        .collection('membercards')
        .doc(docId(memberId, fyStart, cardName))
        .set({
      'memberId': memberId,
      'memberName': memberName,
      'cardName': cardName.trim(),
      'fyStart': fyStart,
      'imageBase64': base64Encode(front),
      'backBase64': back == null ? null : base64Encode(back),
      'sizeBytes': front.length + (back?.length ?? 0),
      'uploadedAt': FieldValue.serverTimestamp(),
      'uploadedBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }
}
