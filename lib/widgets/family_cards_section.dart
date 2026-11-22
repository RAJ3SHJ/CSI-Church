import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/card_service.dart';
import '../screens/card_viewer_screen.dart';
import 'card_draft_section.dart';

/// Opens the upload form for one holder and year (front, optional back; camera or
/// gallery) and saves it. If a card already exists its photos are loaded so either
/// side can be changed on its own. Returns true if saved.
Future<bool> showCardUploadDialog(
  BuildContext context, {
  required String memberId,
  required String memberName,
  required int fy,
  required CardHolder holder,
  Map<String, dynamic>? existing,
}) async {
  final draft = CardDraft(
    fy: fy,
    holder: holder,
    front: existing == null ? null : base64Decode(existing['imageBase64'] as String),
    back: (existing == null || ((existing['backBase64'] ?? '') as String).isEmpty)
        ? null
        : base64Decode(existing['backBase64'] as String),
  );
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(existing == null
            ? 'Upload card · ${holder.name}'
            : 'Update card · ${holder.name}'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: CardDraftSection(
              memberId: memberId,
              memberName: memberName,
              draft: draft,
              lockFyAndName: true,
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
  if (ok != true) return false;
  try {
    await CardService.save(
      memberId: memberId,
      memberName: memberName,
      fyStart: fy,
      holderId: holder.id,
      cardName: draft.holder!.name,
      front: draft.front!,
      back: draft.back,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Card saved for ${holder.name} · ${CardService.fyLabel(fy)}'),
          backgroundColor: AppTheme.success));
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save the card: $e'), backgroundColor: AppTheme.error));
    }
    return false;
  }
}

/// Add Monthly Subscription: the member's whole family. One row per card holder showing the
/// card for the chosen financial year, with View and Upload / Update on each row,
/// and "+ Add family member". Cards stay listed every time the member is opened.
class FamilyCardsSection extends StatefulWidget {
  final String memberId;
  final String memberName;
  const FamilyCardsSection({super.key, required this.memberId, required this.memberName});

  @override
  State<FamilyCardsSection> createState() => _FamilyCardsSectionState();
}

class _FamilyCardsSectionState extends State<FamilyCardsSection> {
  int _fy = CardService.currentFyStart();

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _addMember() async {
    final name = await askHolderName(context, title: 'Add family member');
    if (name == null) return;
    try {
      await CardService.addHolder(widget.memberId, name);
    } catch (e) {
      _toast('Could not save the name: $e');
    }
  }

  Future<void> _rename(CardHolder h) async {
    final name = await askHolderName(context, title: 'Edit card holder name', initial: h.name);
    if (name == null || name == h.name) return;
    try {
      await CardService.renameHolder(widget.memberId, h.id, name);
      _toast('Name updated for all years.');
    } catch (e) {
      _toast('Could not rename: $e');
    }
  }

  void _view(CardHolder h, Map<String, dynamic> card) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardViewerScreen(
          title: '${widget.memberName} · ${h.name} · ${CardService.fyLabel(_fy)}',
          frontBase64: card['imageBase64'] as String,
          backBase64: card['backBase64'] as String?,
          fileName: '${widget.memberId}_${CardService.fyName(_fy)}_${h.id}',
          allowDownload: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cur = CardService.currentFyStart();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('members')
          .where('memberId', isEqualTo: widget.memberId)
          .limit(1)
          .snapshots(),
      builder: (context, memberSnap) {
        final member = (memberSnap.data?.docs.isEmpty ?? true) ? null : memberSnap.data!.docs.first.data();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('membercards')
              .where('memberId', isEqualTo: widget.memberId)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text('Could not load cards: ${snap.error}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.error));
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              );
            }
            final all = CardService.latestPerHolder(snap.data!.docs.map((d) => d.data()));
            final holders = CardService.mergeHolders(member, all, widget.memberName);
            // Cards of the chosen year by holder.
            final byHolder = <String, Map<String, dynamic>>{
              for (final c in all)
                if ((c['fyStart'] as num?)?.toInt() == _fy) CardService.holderIdOf(c): c,
            };
            final open = CardService.isOpen(_fy);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final fy in <int>{cur, cur + 1, ...all.map((c) => (c['fyStart'] as num?)?.toInt() ?? cur)}
                        .where((y) => y >= cur - 5)
                        .toList()
                      ..sort((a, b) => b.compareTo(a)))
                      GestureDetector(
                        onTap: () => setState(() => _fy = fy),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _fy == fy ? AppTheme.navy : AppTheme.navyLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(CardService.fyLabel(fy),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _fy == fy ? AppTheme.white : AppTheme.navy)),
                        ),
                      ),
                  ],
                ),
                if (!open)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('This financial year is closed: cards can be viewed but not changed.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ),
                const SizedBox(height: 10),
                for (final h in holders) _row(h, byHolder[h.id], open),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: _addMember,
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('Add family member'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _row(CardHolder h, Map<String, dynamic>? card, bool open) {
    final has = card != null;
    final hasBack = has && ((card['backBase64'] ?? '') as String).isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: has ? AppTheme.navyLight : AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(has ? Icons.credit_card_rounded : Icons.credit_card_off_outlined,
              color: has ? AppTheme.navy : AppTheme.textSecondary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(h.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.navy)),
                    ),
                    InkWell(
                      onTap: () => _rename(h),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.edit_outlined, size: 16, color: AppTheme.navy),
                      ),
                    ),
                  ],
                ),
                Text(
                    has
                        ? 'Uploaded${hasBack ? ' · front + back' : ' · front only'}'
                        : 'No card for ${CardService.fyLabel(_fy)} yet',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          if (has)
            TextButton(onPressed: () => _view(h, card), child: const Text('View')),
          if (open)
            TextButton(
              onPressed: () => showCardUploadDialog(
                context,
                memberId: widget.memberId,
                memberName: widget.memberName,
                fy: _fy,
                holder: h,
                existing: card,
              ),
              child: Text(has ? 'Update' : 'Upload'),
            ),
        ],
      ),
    );
  }
}
