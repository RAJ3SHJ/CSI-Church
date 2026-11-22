import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/card_service.dart';
import '../screens/card_viewer_screen.dart';

/// Admin view: every card already uploaded for a member (all years), live from
/// the database, with a View button for each. Shown on the Add Donation screen.
class ExistingCardsList extends StatelessWidget {
  final String memberId;
  final String memberName;
  const ExistingCardsList({super.key, required this.memberId, required this.memberName});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('members')
          .where('memberId', isEqualTo: memberId)
          .limit(1)
          .snapshots(),
      builder: (context, memberSnap) {
        final member = (memberSnap.data?.docs.isEmpty ?? true) ? null : memberSnap.data!.docs.first.data();
        final names = {for (final h in CardService.holdersFromMember(member)) h.id: h.name};
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('membercards')
              .where('memberId', isEqualTo: memberId)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text('Could not load existing cards: ${snap.error}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.error));
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: LinearProgressIndicator(),
              );
            }
            final cards = snap.data!.docs.map((d) => d.data()).toList()
              ..sort((a, b) {
                final fa = (a['fyStart'] as num?)?.toInt() ?? 0;
                final fb = (b['fyStart'] as num?)?.toInt() ?? 0;
                if (fa != fb) return fb.compareTo(fa);
                return CardService.displayName(a, names).compareTo(CardService.displayName(b, names));
              });
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.navyLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Already uploaded for $memberName (${cards.length})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.navy)),
                  if (cards.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('No cards uploaded yet.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ),
                  for (final c in cards) _row(context, c, names),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> c, Map<String, String> names) {
    final name = CardService.displayName(c, names);
    final fy = (c['fyStart'] as num?)?.toInt() ?? 0;
    final hasBack = ((c['backBase64'] ?? '') as String).isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Icon(Icons.credit_card_rounded, size: 18, color: AppTheme.navy),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$name · ${CardService.fyLabel(fy)}${hasBack ? ' · front + back' : ''}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CardViewerScreen(
                  title: '$memberName · $name · ${CardService.fyLabel(fy)}',
                  frontBase64: c['imageBase64'] as String,
                  backBase64: c['backBase64'] as String?,
                  fileName: '${memberId}_${CardService.fyName(fy)}_${CardService.holderIdOf(c)}',
                  allowDownload: true,
                ),
              ),
            ),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}
