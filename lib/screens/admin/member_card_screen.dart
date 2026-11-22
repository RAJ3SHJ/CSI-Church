import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../services/card_service.dart';
import '../../widgets/card_draft_section.dart';
import '../card_viewer_screen.dart';

/// Admin / Super Admin: view and add a member's Monthly Subscription cards.
/// A member can have several cards per financial year (Father, Mother, Wife...).
class MemberCardScreen extends StatefulWidget {
  final String memberId;
  final String memberName;
  const MemberCardScreen({super.key, required this.memberId, required this.memberName});

  @override
  State<MemberCardScreen> createState() => _MemberCardScreenState();
}

class _MemberCardScreenState extends State<MemberCardScreen> {
  bool _busy = false;
  Map<String, String> _holderNames = {};
  StreamSubscription? _memberSub;

  @override
  void initState() {
    super.initState();
    // Saved card holder names (renames show here straight away).
    _memberSub = FirebaseFirestore.instance
        .collection('members')
        .where('memberId', isEqualTo: widget.memberId)
        .limit(1)
        .snapshots()
        .listen((snap) {
      final data = snap.docs.isEmpty ? null : snap.docs.first.data();
      if (mounted) {
        setState(() => _holderNames = {
              for (final h in CardService.holdersFromMember(data)) h.id: h.name,
            });
      }
    });
  }

  @override
  void dispose() {
    _memberSub?.cancel();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// Opens the upload form. [replace] prefills year and name of an existing card.
  Future<void> _openForm({Map<String, dynamic>? replace}) async {
    final draft = replace == null
        ? CardDraft()
        : CardDraft(
            fy: (replace['fyStart'] as num).toInt(),
            holder: CardHolder(CardService.holderIdOf(replace),
                CardService.displayName(replace, _holderNames)),
            // Existing photos are loaded so either side can be changed on its own.
            front: base64Decode(replace['imageBase64'] as String),
            back: ((replace['backBase64'] ?? '') as String).isEmpty
                ? null
                : base64Decode(replace['backBase64'] as String));
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(replace == null ? 'Add card for ${widget.memberName}' : 'Update card'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: CardDraftSection(
                memberId: widget.memberId,
                memberName: widget.memberName,
                draft: draft,
                lockFyAndName: replace != null,
                onChanged: () => setD(() {}),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: draft.isValid ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    setState(() => _busy = true);
    try {
      final exists = await CardService.exists(widget.memberId, draft.fy, draft.holder!.id);
      if (exists && replace == null) {
        if (!mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Replace existing card?'),
            content: Text('"${draft.holder!.name}" already has a card for ${CardService.fyLabel(draft.fy)}. Saving will replace it.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Replace')),
            ],
          ),
        );
        if (ok != true) return;
      }
      await CardService.save(
        memberId: widget.memberId,
        memberName: widget.memberName,
        fyStart: draft.fy,
        holderId: draft.holder!.id,
        cardName: draft.holder!.name,
        front: draft.front!,
        back: draft.back,
      );
      _snack('Card "${draft.holder!.name}" saved for ${CardService.fyLabel(draft.fy)}.');
    } catch (e) {
      _snack('Could not save the card: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = CardService.currentFyStart();
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.white,
        title: Text('Cards · ${widget.memberName}', style: const TextStyle(fontSize: 16)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.white,
        onPressed: _busy ? null : () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Card'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('membercards')
            .where('memberId', isEqualTo: widget.memberId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load cards: ${snap.error}', textAlign: TextAlign.center),
            ));
          }
          final byYear = <int, List<Map<String, dynamic>>>{};
          for (final m in CardService.latestPerHolder(
              (snap.data?.docs ?? <QueryDocumentSnapshot>[]).map((d) => d.data() as Map<String, dynamic>))) {
            final fy = (m['fyStart'] as num?)?.toInt();
            if (fy != null) byYear.putIfAbsent(fy, () => []).add(m);
          }
          final years = <int>{cur + 1, cur, ...byYear.keys}.toList()
            ..sort((a, b) => b.compareTo(a));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              Text('${widget.memberName} · ${widget.memberId}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.navy)),
              const SizedBox(height: 4),
              const Text('Several cards per year are allowed (Father, Mother, Wife...). Once a financial year is over it is closed: cards can be viewed but not added or changed.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              for (final fy in years) _yearBlock(fy, byYear[fy] ?? const []),
              if (_busy) const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _yearBlock(int fy, List<Map<String, dynamic>> source) {
    final open = CardService.isOpen(fy);
    // Copy first: the default empty list is unmodifiable and cannot be sorted.
    final cards = [...source];
    cards.sort((a, b) => CardService.displayName(a, _holderNames).compareTo(CardService.displayName(b, _holderNames)));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(CardService.fyLabel(fy),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.navy)),
              const SizedBox(width: 8),
              if (!open)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.navyLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Closed',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (cards.isEmpty)
            const Text('No cards uploaded',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          for (final c in cards) _cardRow(fy, c, open),
        ],
      ),
    );
  }

  Widget _cardRow(int fy, Map<String, dynamic> c, bool open) {
    final name = CardService.displayName(c, _holderNames);
    final hasBack = ((c['backBase64'] ?? '') as String).isNotEmpty;
    final ts = c['uploadedAt'];
    String when = '';
    if (ts is Timestamp) {
      final d = ts.toDate();
      when = 'Uploaded ${d.day}/${d.month}/${d.year}';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Icon(Icons.credit_card_rounded, color: AppTheme.navy, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    ),
                    InkWell(
                      onTap: () async {
                        final nn = await askHolderName(context,
                            title: 'Edit card holder name', initial: name);
                        if (nn == null || nn == name) return;
                        try {
                          await CardService.renameHolder(
                              widget.memberId, CardService.holderIdOf(c), nn);
                          _snack('Name updated for all years.');
                        } catch (e) {
                          _snack('Could not rename: $e');
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.edit_outlined, size: 16, color: AppTheme.navy),
                      ),
                    ),
                  ],
                ),
                Text('${hasBack ? 'Front + back' : 'Front only'}${when.isEmpty ? '' : ' · $when'}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => CardViewerScreen(
                title: '${widget.memberName} · $name · ${CardService.fyLabel(fy)}',
                frontBase64: c['imageBase64'] as String,
                backBase64: c['backBase64'] as String?,
                fileName: '${widget.memberId}_${CardService.fyName(fy)}_${CardService.holderIdOf(c)}',
                allowDownload: true,
              ),
            )),
            child: const Text('View'),
          ),
          if (open)
            TextButton(
              onPressed: _busy ? null : () => _openForm(replace: c),
              child: const Text('Update'),
            ),
        ],
      ),
    );
  }
}
