import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Admin / Super Admin master: church contacts (Name + Designation + Phone Number).
/// Shown to everyone on the public "Contact Us" page.
class AdminContactsScreen extends StatefulWidget {
  const AdminContactsScreen({super.key});

  @override
  State<AdminContactsScreen> createState() => _AdminContactsScreenState();
}

class _AdminContactsScreenState extends State<AdminContactsScreen> {
  final _db = FirebaseFirestore.instance;

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.error : AppTheme.success,
    ));
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final designation = TextEditingController();
    final phone = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> save() async {
            if (!formKey.currentState!.validate()) return;
            setLocal(() => saving = true);
            try {
              await _db.collection('contacts').add({
                'name': name.text.trim(),
                'designation': designation.text.trim(),
                'phone': phone.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _snack('Contact added');
            } catch (e) {
              setLocal(() => saving = false);
              _snack('Could not save: $e', error: true);
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Add Contact',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.navy)),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Name *'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: designation,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          labelText: 'Designation *', hintText: 'e.g. Secretary, Treasurer'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Designation is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: 'Phone Number *', hintText: '+91 00000 00000'),
                      validator: (v) {
                        final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                        return digits.length < 10 ? 'Enter a valid phone number' : null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: saving ? null : save,
                style: ElevatedButton.styleFrom(minimumSize: const Size(96, 44)),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.white))
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    name.dispose();
    designation.dispose();
    phone.dispose();
  }

  Future<void> _delete(DocumentSnapshot doc) async {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete contact?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        content: Text('"${d['name'] ?? ''}" will be removed from the Contact Us page.',
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error, minimumSize: const Size(88, 40)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await doc.reference.delete();
      _snack('Contact deleted');
    } catch (e) {
      _snack('Could not delete: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.white,
        title: const Text('Contact Us (Master)', style: TextStyle(fontSize: 16)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.white,
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add Contact'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('contacts').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load contacts: ${snap.error}', textAlign: TextAlign.center),
            ));
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No contacts yet.\nTap "Add Contact" to add one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(16),
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
                                  fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          if ((d['designation'] ?? '').toString().trim().isNotEmpty)
                            Text((d['designation']).toString(),
                                style: const TextStyle(fontSize: 13, color: AppTheme.navy)),
                          const SizedBox(height: 2),
                          Text((d['phone'] ?? '').toString(),
                              style: const TextStyle(fontSize: 13, color: Color(0xFFD32F2F))),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _delete(docs[i]),
                      icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                      tooltip: 'Delete',
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
