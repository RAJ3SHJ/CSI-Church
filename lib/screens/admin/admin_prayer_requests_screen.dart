import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Small red count of unread prayer requests, shown on the admin dashboards.
class PrayerUnreadBadge extends StatelessWidget {
  const PrayerUnreadBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('prayer_requests').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final unread = snap.data!.docs
            .where((d) => (d.data() as Map<String, dynamic>)['isRead'] != true)
            .length;
        if (unread == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: const Color(0xFFD32F2F), borderRadius: BorderRadius.circular(12)),
          child: Text('$unread new',
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        );
      },
    );
  }
}

/// Admin list of prayer requests sent by members. New ones are highlighted
/// until the admin marks them as read.
class AdminPrayerRequestsScreen extends StatelessWidget {
  const AdminPrayerRequestsScreen({super.key});

  String _date(Timestamp? t) {
    if (t == null) return '';
    final d = t.toDate();
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.white,
        title: const Text('Prayer Requests', style: TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () async {
              final snap =
                  await FirebaseFirestore.instance.collection('prayer_requests').get();
              final batch = FirebaseFirestore.instance.batch();
              for (final d in snap.docs) {
                if ((d.data())['isRead'] != true) batch.update(d.reference, {'isRead': true});
              }
              await batch.commit();
            },
            child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('prayer_requests').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Could not load: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.navy));
          }
          final docs = [...snap.data!.docs]..sort((a, b) {
              final ta = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final tb = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              if (ta == null && tb == null) return 0;
              if (ta == null) return -1;
              if (tb == null) return 1;
              return tb.compareTo(ta);
            });
          if (docs.isEmpty) {
            return const Center(child: Text('No prayer requests yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final unread = d['isRead'] != true;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: unread ? AppTheme.navyLight : AppTheme.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: unread ? AppTheme.navy : AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text((d['memberName'] ?? 'Member').toString(),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.navy)),
                        ),
                        Text(_date(d['createdAt'] as Timestamp?),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text((d['request'] ?? '').toString(),
                        style: const TextStyle(fontSize: 14, height: 1.4)),
                    if (unread)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => docs[i].reference.update({'isRead': true}),
                          child: const Text('Mark as read'),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
