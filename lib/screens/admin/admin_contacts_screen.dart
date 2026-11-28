import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Admin / Super Admin master: church contacts (Name + Designation + Phone Number).
/// Shown to everyone on the public "Contact Us" page.
class AdminContactsScreen extends StatefulWidget {
  const AdminContactsScreen({super.key});

  @override
  State<AdminContactsScreen> createState() => _AdminContactsScreenState();
}

class _AdminContactsScreenState extends State<AdminContactsScreen> with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  late final TabController _tabs = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));
  String get _group => _tabs.index == 0 ? 'office' : 'media';

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.error : AppTheme.success,
    ));
  }

  Future<void> _openForm({DocumentSnapshot? doc, String group = 'office'}) async {
    final existing = (doc?.data() as Map<String, dynamic>?) ?? {};
    final name = TextEditingController(text: (existing['name'] ?? '').toString());
    final designation = TextEditingController(text: (existing['designation'] ?? '').toString());
    final phone = TextEditingController(text: (existing['phone'] ?? '').toString());
    String photo = (existing['photoBase64'] ?? '').toString();
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
              final payload = {
                'name': name.text.trim(),
                'designation': designation.text.trim(),
                'phone': phone.text.trim(),
                'photoBase64': photo,
                'group': doc == null ? group : (existing['group'] ?? 'office'),
              };
              if (doc == null) {
                await _db.collection('contacts').add({
                  ...payload,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              } else {
                await doc.reference.update(payload);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _snack(doc == null ? 'Contact added' : 'Contact updated');
            } catch (e) {
              setLocal(() => saving = false);
              _snack('Could not save: $e', error: true);
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(doc == null ? 'Add Contact' : 'Edit Contact',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.navy)),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.navyLight,
                          backgroundImage:
                              photo.isEmpty ? null : MemoryImage(base64Decode(photo)),
                          child: photo.isEmpty
                              ? const Icon(Icons.person_outline, color: AppTheme.navy)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: () async {
                            final x = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 240,
                                maxHeight: 240,
                                imageQuality: 70);
                            if (x == null) return;
                            final Uint8List bytes = await x.readAsBytes();
                            if (bytes.length > 60 * 1024) {
                              _snack('Photo is too large. Please pick a smaller one.', error: true);
                              return;
                            }
                            setLocal(() => photo = base64Encode(bytes));
                          },
                          icon: const Icon(Icons.photo_camera_outlined, size: 18),
                          label: Text(photo.isEmpty ? 'Add photo' : 'Change'),
                        ),
                        if (photo.isNotEmpty)
                          IconButton(
                            onPressed: () => setLocal(() => photo = ''),
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Remove photo',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                          labelText: group == 'media' ? 'Role *' : 'Designation *', hintText: group == 'media' ? 'e.g. Sound, Camera, Live' : 'e.g. Secretary, Treasurer'),
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
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'Office Bearers'), Tab(text: 'Media Support')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.white,
        onPressed: () => _openForm(group: _group),
        icon: const Icon(Icons.add),
        label: Text(_tabs.index == 0 ? 'Add Office Bearer' : 'Add Media Support'),
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
          final docs = snap.data!.docs.where((x) {
            final g = ((x.data() as Map<String, dynamic>)['group'] ?? 'office').toString();
            return g == _group;
          }).toList()
            ..sort((a, b) {
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
                child: Text('Nothing here yet.\nTap the button below to add one.',
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
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.navyLight,
                      backgroundImage: (d['photoBase64'] ?? '').toString().isEmpty
                          ? null
                          : MemoryImage(base64Decode(d['photoBase64'].toString())),
                      child: (d['photoBase64'] ?? '').toString().isEmpty
                          ? const Icon(Icons.person_outline, color: AppTheme.navy, size: 20)
                          : null,
                    ),
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
                      onPressed: () => _openForm(doc: docs[i]),
                      icon: const Icon(Icons.edit_outlined, color: AppTheme.navy),
                      tooltip: 'Edit',
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
