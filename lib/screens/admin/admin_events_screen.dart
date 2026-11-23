import '../../services/event_photo_service.dart';
import 'admin_event_photos_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Admin / Super Admin screen to manage Events and Upcoming Events.
/// Members see the same data (read-only) on their Events screen.
class AdminEventsScreen extends StatefulWidget {
  /// 0 = Events tab, 1 = Upcoming Events tab, 2 = Announcements tab
  final int initialTab;
  const AdminEventsScreen({super.key, this.initialTab = 0});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _db = FirebaseFirestore.instance;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
    _tab.addListener(() {
      if (!_tab.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.error : AppTheme.success,
    ));
  }

  // ───────────────────────── EVENT FORM ─────────────────────────

  Future<void> _openEventForm({
    DocumentSnapshot? doc,
    String collection = 'events',
    String noun = 'Event',
  }) async {
    final data = (doc?.data() as Map<String, dynamic>?) ?? {};
    final title = TextEditingController(text: data['title'] as String? ?? '');
    final desc =
        TextEditingController(text: data['description'] as String? ?? '');
    final loc = TextEditingController(text: data['location'] as String? ?? '');
    final formKey = GlobalKey<FormState>();
    final photos = EventPhotosController();
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
                'title': title.text.trim(),
                'description': desc.text.trim(),
                'location': loc.text.trim(),
              };
              DocumentReference<Map<String, dynamic>> ref;
              if (doc == null) {
                ref = await _db.collection(collection).add({
                  ...payload,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              } else {
                ref = doc.reference as DocumentReference<Map<String, dynamic>>;
                await ref.update({
                  ...payload,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
              if (photos.hasChanges) await photos.applyTo(ref);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _snack(doc == null ? '$noun added' : '$noun updated');
            } catch (e) {
              setLocal(() => saving = false);
              _snack('Could not save: $e', error: true);
            }
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(doc == null ? 'Add $noun' : 'Edit $noun',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.navy)),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: title,
                        decoration: const InputDecoration(labelText: 'Title *'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Title is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: desc,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: loc,
                        decoration: const InputDecoration(labelText: 'Venue'),
                      ),
                      const SizedBox(height: 16),
                      EventPhotosField(
                          controller: photos, existing: EventPhotoService.photosOf(data)),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: saving ? null : save,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(96, 44)),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.white))
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    title.dispose();
    desc.dispose();
    loc.dispose();
  }

  // ───────────────────────── ANNOUNCEMENT FORM ─────────────────────────

  Future<void> _openAnnouncementForm({DocumentSnapshot? doc}) async {
    final data = (doc?.data() as Map<String, dynamic>?) ?? {};
    final title = TextEditingController(text: data['title'] as String? ?? '');
    final desc =
        TextEditingController(text: data['description'] as String? ?? '');
    final formKey = GlobalKey<FormState>();
    final photos = EventPhotosController();
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
                'title': title.text.trim(),
                'description': desc.text.trim(),
              };
              DocumentReference<Map<String, dynamic>> ref;
              if (doc == null) {
                ref = await _db.collection('announcements').add({
                  ...payload,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              } else {
                ref = doc.reference as DocumentReference<Map<String, dynamic>>;
                await ref.update({
                  ...payload,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
              if (photos.hasChanges) await photos.applyTo(ref);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _snack(doc == null
                  ? 'Upcoming event posted'
                  : 'Upcoming event updated');
            } catch (e) {
              setLocal(() => saving = false);
              _snack('Could not save: $e', error: true);
            }
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(doc == null ? 'New Upcoming Event' : 'Edit Upcoming Events',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.navy)),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: title,
                        decoration: const InputDecoration(labelText: 'Title *'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Title is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: desc,
                        maxLines: 5,
                        decoration: const InputDecoration(
                            labelText: 'Message', alignLabelWithHint: true),
                      ),
                      const SizedBox(height: 16),
                      EventPhotosField(
                          controller: photos, existing: EventPhotoService.photosOf(data)),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: saving ? null : save,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(96, 44)),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.white))
                    : Text(doc == null ? 'Post' : 'Save'),
              ),
            ],
          );
        },
      ),
    );

    title.dispose();
    desc.dispose();
  }

  // ───────────────────────── DELETE ─────────────────────────

  Future<void> _confirmDelete(DocumentSnapshot doc, String what) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final name = data['title'] as String? ?? what;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete $what?',
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        content: Text('"$name" will be removed for all members. This cannot be undone.',
            style: const TextStyle(
                fontSize: 14, color: AppTheme.textSecondary, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                minimumSize: const Size(88, 40)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await doc.reference.delete();
      _snack('$what deleted');
    } catch (e) {
      _snack('Could not delete: $e', error: true);
    }
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.white,
        onPressed: () {
          if (_tab.index == 0) {
            _openEventForm();
          } else if (_tab.index == 1) {
            _openAnnouncementForm();
          } else {
            _openEventForm(collection: 'notices', noun: 'Announcement');
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_tab.index == 0
            ? 'Add Event'
            : _tab.index == 1
                ? 'New Upcoming Event'
                : 'Add Announcement'),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Container(
            color: AppTheme.navy,
            child: TabBar(
              controller: _tab,
              indicatorColor: AppTheme.white,
              indicatorWeight: 3,
              labelColor: AppTheme.white,
              unselectedLabelColor: Colors.white54,
              labelStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Events'),
                Tab(text: 'Upcoming Events'),
                Tab(text: 'Announcements'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildEventsList(),
                _buildAnnouncementsList(),
                _buildEventsList(collection: 'notices', noun: 'announcement'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.navy,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppTheme.white, size: 20),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          Text(_tab.index == 0 ? 'Events' : _tab.index == 1 ? 'Upcoming Events' : 'Announcements',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.white)),
        ],
      ),
    );
  }

  Widget _empty(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.border),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList({String collection = 'events', String noun = 'event'}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection(collection).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _empty(Icons.error_outline, 'Could not load ${noun}s: ${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.navy));
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
          return _empty(Icons.event_outlined,
              'No ${noun}s yet.\nTap "Add ${noun[0].toUpperCase()}${noun.substring(1)}" to publish one.');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final d = doc.data() as Map<String, dynamic>;
            final loc = (d['location'] as String? ?? '').trim();
            final desc = (d['description'] as String? ?? '').trim();
            return _card(
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: AppTheme.navyLight,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.event_outlined,
                    color: AppTheme.navy, size: 22),
              ),
              title: d['title'] as String? ?? '',
              lines: [
                if (desc.isNotEmpty) desc,
                if (loc.isNotEmpty) 'Venue: $loc',
              ],
              onEdit: () => _openEventForm(
                  doc: doc,
                  collection: collection,
                  noun: '${noun[0].toUpperCase()}${noun.substring(1)}'),
              onDelete: () => _confirmDelete(doc, noun),
            );
          },
        );
      },
    );
  }

  Widget _buildAnnouncementsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _empty(
              Icons.error_outline, 'Could not load upcoming events: ${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.navy));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _empty(Icons.campaign_outlined,
              'No upcoming events yet.\nTap "New Upcoming Event" to post one.');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final d = doc.data() as Map<String, dynamic>;
            return _card(
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: AppTheme.navyLight,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.campaign_outlined,
                    color: AppTheme.navy, size: 22),
              ),
              title: d['title'] as String? ?? '',
              lines: [
                (d['description'] as String? ?? '').trim(),
              ].where((s) => s.isNotEmpty).toList(),
              onEdit: () => _openAnnouncementForm(doc: doc),
              onDelete: () => _confirmDelete(doc, 'upcoming event'),
            );
          },
        );
      },
    );
  }

  Widget _card({
    required Widget leading,
    required String title,
    required List<String> lines,
    String? badge,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    VoidCallback? onPhotos,
    int photoCount = 0,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badge == 'Upcoming'
                              ? AppTheme.successLight
                              : AppTheme.navyLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(badge,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: badge == 'Upcoming'
                                    ? AppTheme.success
                                    : AppTheme.textSecondary)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(l,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                            height: 1.4)),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.navy,
                          padding: const EdgeInsets.symmetric(horizontal: 8)),
                    ),
                    if (onPhotos != null)
                      TextButton.icon(
                        onPressed: onPhotos,
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: Text(photoCount == 0 ? 'Photos' : 'Photos ($photoCount)'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.navy,
                            padding: const EdgeInsets.symmetric(horizontal: 8)),
                      ),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          padding: const EdgeInsets.symmetric(horizontal: 8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
