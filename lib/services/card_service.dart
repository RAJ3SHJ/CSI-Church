import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A saved card holder of a member (Father, Mother, Wife...). The id never
/// changes, so renaming only changes the shown name.
class CardHolder {
  final String id;
  final String name;
  const CardHolder(this.id, this.name);
  Map<String, dynamic> toMap() => {'id': id, 'name': name};
}

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

  /// One card per holder per member per financial year; same id = replace.
  static String docId(String memberId, int fyStart, String holderId) =>
      '${memberId}_${fyStart}_$holderId';

  /// Holder id of a stored card (older cards had no holderId: derive it from
  /// the name they were saved with, which is how their document id was made).
  static String holderIdOf(Map<String, dynamic> m) {
    final h = (m['holderId'] ?? '').toString();
    if (h.isNotEmpty) return h;
    return slug((m['cardName'] ?? m['memberName'] ?? 'card').toString());
  }

  /// Name to show for a stored card: the holder's current saved name if known,
  /// else the name stored on the card.
  static String displayName(Map<String, dynamic> m, [Map<String, String>? holderNames]) {
    final fromList = holderNames?[holderIdOf(m)];
    if (fromList != null && fromList.trim().isNotEmpty) return fromList;
    final n = (m['cardName'] ?? '').toString().trim();
    if (n.isNotEmpty) return n;
    final mn = (m['memberName'] ?? '').toString().trim();
    return mn.isNotEmpty ? mn : 'Card';
  }

  /// Member document (members are looked up by memberId, e.g. CSI-00002).
  static Future<DocumentReference<Map<String, dynamic>>?> memberRef(String memberId) async {
    final q = await FirebaseFirestore.instance
        .collection('members')
        .where('memberId', isEqualTo: memberId)
        .limit(1)
        .get();
    return q.docs.isEmpty ? null : q.docs.first.reference;
  }

  /// Parses holders saved on a member document.
  static List<CardHolder> holdersFromMember(Map<String, dynamic>? member) {
    final raw = member?['cardHolders'];
    if (raw is! List) return [];
    return [
      for (final e in raw)
        if (e is Map && (e['id'] ?? '').toString().isNotEmpty)
          CardHolder(e['id'].toString(), (e['name'] ?? '').toString()),
    ];
  }

  /// The member's saved card holders, plus holders of cards uploaded before
  /// holders existed (so nothing is lost).
  static Future<List<CardHolder>> loadHolders(String memberId) async {
    final ref = await memberRef(memberId);
    final saved = holdersFromMember((await ref?.get())?.data());
    final byId = {for (final h in saved) h.id: h};
    try {
      final cards = await FirebaseFirestore.instance
          .collection('membercards')
          .where('memberId', isEqualTo: memberId)
          .get();
      for (final d in cards.docs) {
        final m = d.data();
        final id = holderIdOf(m);
        byId.putIfAbsent(id, () => CardHolder(id, displayName(m)));
      }
    } catch (_) {}
    return byId.values.toList();
  }

  /// Holders to show right now: saved ones, holders of existing cards, and the
  /// member himself as the first holder when nothing else exists yet.
  static List<CardHolder> mergeHolders(
      Map<String, dynamic>? member, Iterable<Map<String, dynamic>> cards, String memberName) {
    final byId = <String, CardHolder>{for (final h in holdersFromMember(member)) h.id: h};
    for (final m in cards) {
      final id = holderIdOf(m);
      byId.putIfAbsent(id, () => CardHolder(id, displayName(m)));
    }
    if (byId.isEmpty && memberName.trim().isNotEmpty) {
      byId[slug(memberName)] = CardHolder(slug(memberName), memberName.trim());
    }
    return byId.values.toList();
  }

  /// Saves the member's holder list permanently.
  static Future<void> saveHolders(String memberId, List<CardHolder> holders) async {
    final ref = await memberRef(memberId);
    if (ref == null) throw StateError('Member $memberId not found');
    await ref.update({'cardHolders': holders.map((h) => h.toMap()).toList()});
  }

  /// Adds a new holder (permanently) and returns it.
  static Future<CardHolder> addHolder(String memberId, String name) async {
    final holders = await loadHolders(memberId);
    var id = slug(name);
    final taken = holders.map((h) => h.id).toSet();
    var n = 2;
    final base = id;
    while (taken.contains(id)) {
      id = '$base-$n';
      n++;
    }
    final h = CardHolder(id, name.trim());
    await saveHolders(memberId, [...holders, h]);
    return h;
  }

  /// Renames a holder. Cards show the new name everywhere, including closed years.
  static Future<void> renameHolder(String memberId, String holderId, String newName) async {
    final holders = await loadHolders(memberId);
    final found = holders.any((h) => h.id == holderId);
    final updated = [
      for (final h in holders) h.id == holderId ? CardHolder(h.id, newName.trim()) : h,
      // A holder that was only implied (e.g. the member himself) is saved now.
      if (!found) CardHolder(holderId, newName.trim()),
    ];
    await saveHolders(memberId, updated);
  }

  /// The stored card for a holder and year, or null.
  static Future<Map<String, dynamic>?> getCard(String memberId, int fyStart, String holderId) async {
    final d = await FirebaseFirestore.instance
        .collection('membercards')
        .doc(docId(memberId, fyStart, holderId))
        .get();
    return d.exists ? d.data() : null;
  }

  /// True if a card for this holder already exists for the member and year.
  static Future<bool> exists(String memberId, int fyStart, String holderId) async =>
      (await getCard(memberId, fyStart, holderId)) != null;

  /// Saves (or replaces) a card. Past financial years are closed.
  static Future<void> save({
    required String memberId,
    required String memberName,
    required int fyStart,
    required String holderId,
    required String cardName,
    required Uint8List front,
    Uint8List? back,
  }) {
    if (!isOpen(fyStart)) {
      throw StateError('${fyLabel(fyStart)} is closed. Cards can no longer be added or changed.');
    }
    return FirebaseFirestore.instance
        .collection('membercards')
        .doc(docId(memberId, fyStart, holderId))
        .set({
      'memberId': memberId,
      'memberName': memberName,
      'holderId': holderId,
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
