import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../services/firebase_service.dart';
import '../../services/card_service.dart';
import '../../widgets/card_draft_section.dart';

class AddDonationScreen extends StatefulWidget {
  const AddDonationScreen({super.key});
  @override
  State<AddDonationScreen> createState() => _AddDonationScreenState();
}

class _AddDonationScreenState extends State<AddDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _memberSearchController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedCategory = 'Tithe';
  String _selectedPaymentMode = 'Cash';
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;
  bool _isSubmitted = false;
  bool _memberFound = false;
  bool _isSearching = false;
  String _foundMemberName = '';
  String _foundMemberId = '';
  final List<_CardEntry> _cards = [_CardEntry()];
  List<String> _categories = ['Tithe', 'Offering', 'Building Fund', 'Special Fund', 'Charity', 'Missions'];
  final List<String> _paymentModes = ['Cash', 'UPI', 'Cheque', 'Bank Transfer'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('categories')
          .orderBy('name')
          .get();
      if (snap.docs.isNotEmpty && mounted) {
        setState(() {
          _categories = snap.docs
              .map((d) => d.data()['name'] as String? ?? '')
              .where((n) => n.isNotEmpty)
              .toList();
          if (!_categories.contains(_selectedCategory)) {
            _selectedCategory = _categories.first;
          }
        });
      }
    } catch (e) {
      // Keep default categories
    }
  }

  @override
  void dispose() {
    _memberSearchController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _searchMember(String query) async {
    if (query.trim().isEmpty) return;
    setState(() { _isSearching = true; _memberFound = false; });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('members')
          .where('memberId', isEqualTo: query.trim().toUpperCase())
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        setState(() {
          _memberFound = true;
          _foundMemberName = data['name'] ?? '';
          _foundMemberId = data['memberId'] ?? '';
          _cards
            ..clear()
            ..add(_CardEntry());
        });
      } else {
        setState(() { _memberFound = false; _foundMemberName = ''; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member not found. Check the Member ID.'),
              backgroundColor: AppTheme.error),
        );
      }
    } catch (e) {
      setState(() { _memberFound = false; });
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_memberFound) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please search and select a valid member first.')),
      );
      return;
    }

    // Cards with a front photo are uploaded with the donation. Check and confirm first.
    final pending = _cards.where((e) => e.draft.hasPhoto).toList();
    if (pending.isNotEmpty) {
      final seen = <String>{};
      for (final e in pending) {
        final d = e.draft;
        if (d.holder == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please choose the card holder name for every card you are uploading.')),
          );
          return;
        }
        if (!CardService.isOpen(d.fy)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${CardService.fyLabel(d.fy)} is closed. Choose the current or next year.')),
          );
          return;
        }
        if (!seen.add('${d.holder!.id}_${d.fy}')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${d.holder!.name} is added twice for ${CardService.fyLabel(d.fy)}. Keep one.')),
          );
          return;
        }
      }
      final replacing = <String, bool>{};
      for (final e in pending) {
        try {
          replacing['${e.draft.holder!.id}_${e.draft.fy}'] =
              await CardService.exists(_foundMemberId, e.draft.fy, e.draft.holder!.id);
        } catch (_) {}
      }
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(pending.length == 1 ? 'Save donation and card?' : 'Save donation and ${pending.length} cards?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_foundMemberName · $_foundMemberId',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Donation ₹${_amountController.text.trim()}'),
                for (final e in pending) ...[
                  const SizedBox(height: 12),
                  Text('Card: ${e.draft.holder!.name} · ${CardService.fyLabel(e.draft.fy)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (replacing['${e.draft.holder!.id}_${e.draft.fy}'] == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('This card already exists for this year and will be replaced.',
                          style: TextStyle(color: AppTheme.error)),
                    ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: Image.memory(e.draft.front!, fit: BoxFit.contain),
                  ),
                  if (e.draft.back != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Back side attached',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseService.addDonation(
        memberId: _foundMemberId,
        memberName: _foundMemberName,
        amount: double.parse(_amountController.text.trim()),
        category: _selectedCategory,
        mode: _selectedPaymentMode,
        notes: _notesController.text.trim(),
      );
      final cardErrors = <String>[];
      for (final e in _cards.where((e) => e.draft.hasPhoto)) {
        final d = e.draft;
        try {
          await CardService.save(
            memberId: _foundMemberId,
            memberName: _foundMemberName,
            fyStart: d.fy,
            holderId: d.holder!.id,
            cardName: d.holder!.name,
            front: d.front!,
            back: d.back,
          );
        } catch (err) {
          cardErrors.add('${d.holder?.name ?? 'card'}: $err');
        }
      }
      final cardError = cardErrors.isEmpty ? null : cardErrors.join('\n');
      if (mounted) {
        setState(() { _isSubmitting = false; _isSubmitted = true; });
        if (cardError != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Donation saved, but the card could not be saved: $cardError'),
              backgroundColor: AppTheme.error));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2019),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.navy),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _isSubmitted ? _buildSuccess() : _buildForm()),
        ],
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
          const Text('Add Donation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.white)),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Member Search
            Container(
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Member',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.navy)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _memberSearchController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                          ],
                          decoration: const InputDecoration(
                            hintText: 'Enter Member ID (CSI-00123)',
                            prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.navy, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSearching ? null : () =>
                            _searchMember(_memberSearchController.text),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(70, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSearching
                            ? const SizedBox(height: 18, width: 18,
                                child: CircularProgressIndicator(color: AppTheme.white, strokeWidth: 2))
                            : const Text('Find'),
                      ),
                    ],
                  ),
                  if (_memberFound) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.successLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 18),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_foundMemberName,
                                  style: const TextStyle(fontSize: 14,
                                      fontWeight: FontWeight.w600, color: AppTheme.success)),
                              Text(_foundMemberId,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.success)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Amount & Date
            Container(
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Amount (₹)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.navy)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.navy),
                    decoration: const InputDecoration(
                      hintText: '0',
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.navy),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Amount is required';
                      if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Date',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.navy)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, color: AppTheme.navy, size: 18),
                          const SizedBox(width: 10),
                          Text(_formatDate(_selectedDate),
                              style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Category
            Container(
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.navy)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.navy : AppTheme.navyLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(cat,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                                  color: isSelected ? AppTheme.white : AppTheme.navy)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Payment Mode
            Container(
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Mode',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.navy)),
                  const SizedBox(height: 10),
                  Row(
                    children: _paymentModes.map((mode) {
                      final isSelected = _selectedPaymentMode == mode;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedPaymentMode = mode),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.navy : AppTheme.navyLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(mode, textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                                    color: isSelected ? AppTheme.white : AppTheme.navy)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Monthly Collection Card (optional)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Monthly Subscription Card (Optional)',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.navy)),
                      ),
                      if (_memberFound)
                        TextButton(
                          onPressed: () => setState(() => _cards.add(_CardEntry())),
                          child: const Text('Add New Card',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Choose the financial year and the saved card holder (Father, Mother, Wife...), then upload the front and, if there is one, the back. Use Add New Card for another card.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 10),
                  if (!_memberFound)
                    const Text('Search and select a member first to add cards.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))
                  else
                    for (var i = 0; i < _cards.length; i++) ...[
                      if (i > 0) const Divider(height: 28),
                      if (_cards.length > 1)
                        Row(
                          children: [
                            Expanded(
                              child: Text('Card ${i + 1}',
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.navy)),
                            ),
                            if (_cards.length > 1)
                              IconButton(
                                onPressed: () => setState(() => _cards.removeAt(i)),
                                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                                tooltip: 'Remove this card',
                              ),
                          ],
                        ),
                      CardDraftSection(
                        key: _cards[i].key,
                        memberId: _foundMemberId,
                        memberName: _foundMemberName,
                        draft: _cards[i].draft,
                        onChanged: () => setState(() {}),
                      ),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Notes
            Container(
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notes (Optional)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.navy)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Any additional notes...',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(height: 22, width: 22,
                      child: CircularProgressIndicator(color: AppTheme.white, strokeWidth: 2.5))
                  : const Text('Record Donation'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: const BoxDecoration(color: AppTheme.successLight, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 48, color: AppTheme.success),
            ),
            const SizedBox(height: 24),
            const Text('Donation Recorded!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.navy)),
            const SizedBox(height: 12),
            Text('₹${_amountController.text} recorded for $_foundMemberName',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.5)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() {
                _isSubmitted = false;
                _memberFound = false;
                _memberSearchController.clear();
                _amountController.clear();
                _notesController.clear();
                _cards
                  ..clear()
                  ..add(_CardEntry());
              }),
              child: const Text('Add Another Donation',
                  style: TextStyle(color: AppTheme.navy)),
            ),
          ],
        ),
      ),
    );
  }
}

/// One card block on the Add Donation screen.
class _CardEntry {
  final CardDraft draft = CardDraft();
  final Key key = UniqueKey();
}
