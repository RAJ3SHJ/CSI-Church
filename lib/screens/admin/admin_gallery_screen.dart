import 'package:flutter/material.dart';
import '../../services/gallery_service.dart';
import '../../theme/app_theme.dart';
import '../event_gallery_screen.dart';

/// Admin / Super Admin master: upload many photos at once into a gallery album.
class AdminGalleryScreen extends StatefulWidget {
  const AdminGalleryScreen({super.key});

  @override
  State<AdminGalleryScreen> createState() => _AdminGalleryScreenState();
}

class _AdminGalleryScreenState extends State<AdminGalleryScreen> {
  String _cat = 'youth';
  String _progress = '';
  bool _busy = false;

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: error ? AppTheme.error : AppTheme.success));
  }

  Future<void> _upload() async {
    setState(() { _busy = true; _progress = ''; });
    try {
      final n = await GalleryService.pickAndUpload(_cat,
          onProgress: (d, t) { if (mounted) setState(() => _progress = 'Uploading $d of $t...'); });
      if (n > 0) _snack('$n photo(s) added to ${GalleryService.labelOf(_cat)}');
    } catch (e) {
      _snack('Upload failed: $e', error: true);
    }
    if (mounted) setState(() { _busy = false; _progress = ''; });
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This removes it from the gallery.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      try { await GalleryService.remove(p); } catch (e) { _snack('Could not delete: $e', error: true); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.white,
        title: const Text('Gallery', style: TextStyle(fontSize: 18)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _upload,
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(_busy ? 'Uploading...' : 'Add photos'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Wrap(
              spacing: 8,
              children: [
                for (final k in GalleryService.categories.keys)
                  ChoiceChip(
                    label: Text(GalleryService.labelOf(k)),
                    selected: _cat == k,
                    selectedColor: AppTheme.navyLight,
                    onSelected: (_) => setState(() => _cat = k),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _upload,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text('Add photos to ${GalleryService.labelOf(_cat)}'),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.navy),
                ),
                if (_progress.isNotEmpty) Text(_progress),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: GalleryService.col.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return const Center(child: Text('Could not load photos.'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final photos = GalleryService.inCategory(GalleryService.parse(snap.data!), _cat);
                if (photos.isEmpty) return const Center(child: Text('No photos in this album yet.'));
                return GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 150, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: photos.length,
                  itemBuilder: (context, i) => Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: () => openPhotoViewer(context, GalleryService.labelOf(_cat), photos, initial: i),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: networkPhoto(photos[i]['url'].toString())),
                      ),
                      Positioned(
                        top: 4, right: 4,
                        child: InkWell(
                          onTap: () => _delete(photos[i]),
                          child: const CircleAvatar(
                              radius: 13, backgroundColor: Colors.black54,
                              child: Icon(Icons.delete_outline, size: 16, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
