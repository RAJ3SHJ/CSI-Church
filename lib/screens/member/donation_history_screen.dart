import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../services/card_service.dart';
import '../card_viewer_screen.dart';

/// Monthly Subscription: financial-year chips, and under each year the member's
/// cards (Father, Mother, Wife...). Members can view the cards but not download.
class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key});
  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  int _selectedFy = CardService.currentFyStart();
  String _memberId = '';
  String _memberName = '';
  Map<String, String> _holderNames = {};
  StreamSubscription? _memberSub;

  @override
  void initState() {
    super.initState();
    _loadMember();
  }

  void _loadMember() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Listens to the member's own record: id, name and saved card holder names.
    _memberSub = FirebaseFirestore.instance
        .collection('members')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!mounted || !doc.exists) return;
      final data = doc.data();
      setState(() {
        _memberId = data?['memberId'] ?? '';
        _memberName = data?['name'] ?? '';
        _holderNames = {
          for (final h in CardService.holdersFromMember(data)) h.id: h.name,
        };
      });
    });
  }

  @override
  void dispose() {
    _memberSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildHeader(context),
          if (_memberId.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.navy)))
          else
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('membercards')
                    .where('memberId', isEqualTo: _memberId)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Could not load cards: ${snap.error}', textAlign: TextAlign.center),
                      ),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.navy));
                  }
                  final byYear = <int, List<Map<String, dynamic>>>{};
                  for (final m in CardService.latestPerHolder(
                      snap.data!.docs.map((d) => d.data() as Map<String, dynamic>))) {
                    final fy = (m['fyStart'] as num?)?.toInt();
                    if (fy != null) byYear.putIfAbsent(fy, () => []).add(m);
                  }
                  final cur = CardService.currentFyStart();
                  final years = <int>{cur, ...byYear.keys}.toList()
                    ..sort((a, b) => b.compareTo(a));
                  final cards = [...(byYear[_selectedFy] ?? <Map<String, dynamic>>[])]
                    ..sort((a, b) => CardService.displayName(a, _holderNames).compareTo(CardService.displayName(b, _holderNames)));
                  return Column(
                    children: [
                      _buildFilterChips(years),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                          children: [
                            if (cards.isEmpty && _holderNames.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Text(
                                    'Monthly Subscription card for ${CardService.fyLabel(_selectedFy)} is not uploaded yet.',
                                    style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                              ),
                            for (final c in cards) _cardTile(c),
                            // Family members saved by the church but without a card this year.
                            for (final e in _holderNames.entries)
                              if (!cards.any((c) => CardService.holderIdOf(c) == e.key))
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.credit_card_off_outlined,
                                          color: AppTheme.textSecondary),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                            '${e.value} · not uploaded yet for ${CardService.fyLabel(_selectedFy)}',
                                            style: const TextStyle(
                                                fontSize: 14, color: AppTheme.textSecondary)),
                                      ),
                                    ],
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _cardTile(Map<String, dynamic> c) {
    final name = CardService.displayName(c, _holderNames);
    final hasBack = ((c['backBase64'] ?? '') as String).isNotEmpty;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CardViewerScreen(
            title: '$name · ${CardService.fyLabel(_selectedFy)}',
            frontBase64: c['imageBase64'] as String,
            backBase64: c['backBase64'] as String?,
            fileName: '${_memberId}_${CardService.fyName(_selectedFy)}_${CardService.holderIdOf(c)}',
          ),
        ),
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.navyLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.credit_card_rounded, color: AppTheme.navy, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.navy)),
                  const SizedBox(height: 2),
                  Text(
                      '${CardService.fyLabel(_selectedFy)}${hasBack ? ' · tap to flip' : ''}',
                      style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppTheme.navy,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 16, left: 16, right: 16,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.white, size: 20),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          const Text('Monthly Subscription',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.white)),
        ],
      ),
    );
  }

  Widget _buildFilterChips(List<int> years) {
    return Container(
      color: AppTheme.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: years.map((fy) {
            final isSelected = _selectedFy == fy;
            return GestureDetector(
              onTap: () => setState(() => _selectedFy = fy),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.navy : AppTheme.navyLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(CardService.fyLabel(fy),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? AppTheme.white : AppTheme.navy)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
