import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Public "Contact Us" page: names and phone numbers managed by admins.
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.white,
        title: const Text('Contact Us', style: TextStyle(fontSize: 18)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('contacts').snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(child: Text('Could not load contacts right now.'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.navy));
              }
              final docs = [...snap.data!.docs]..sort((a, b) {
                  final ta = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  final tb = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  if (ta == null && tb == null) return 0;
                  if (ta == null) return 1;
                  if (tb == null) return -1;
                  return ta.compareTo(tb);
                });
              if (docs.isEmpty) {
                return const Center(child: Text('No contacts added yet.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_outlined, color: AppTheme.navy),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((d['name'] ?? '').toString(),
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.navy)),
                              const SizedBox(height: 2),
                              SelectableText((d['phone'] ?? '').toString(),
                                  style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
