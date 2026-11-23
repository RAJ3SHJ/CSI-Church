import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/event_photo_service.dart';
import '../../theme/app_theme.dart';
import '../event_gallery_screen.dart';

/// Admin: add and remove the photos of one event.
class AdminEventPhotosScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> eventRef;
  final String title;
  const AdminEventPhotosScreen({super.key, required this.eventRef, required this.title});

  @override
  State<AdminEventPhotosScreen> createState() => _AdminEventPhotosScreenState();
}

class _AdminEventPhotosScreenState extends State<AdminEventPhotosScreen> {
  String? _progress;

  Future<void> _add() async {
    try {
      setState(() => _progress = 'Uploading...');
      final n = await EventPhotoService.pickAndUpload(widget.eventRef,
          onProgress: (d, t) => setState(() => _progress = 'Uploading $d of $t...'));
      if (!mounted) return;
      if (n > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$n photo${n == 1 ? '' : 's'} added'),
            backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _remove(Map<String, dynamic> photo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this photo?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await EventPhotoService.remove(widget.eventRef, photo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.white,
        title: Text('Photos · ${widget.title}', style: const TextStyle(fontSize: 17)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _progress == null ? _add : null,
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.white,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(_progress ?? 'Add Photos'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: widget.eventRef.snapshots(),
        builder: (context, snap) {
          final photos = EventPhotoService.photosOf(snap.data?.data() ?? {});
          if (photos.isEmpty) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No photos yet.\nTap "Add Photos" to upload.',
                  textAlign: TextAlign.center),
            ));
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: photos.length,
            itemBuilder: (context, i) => Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: networkPhoto(photos[i]['url'].toString()),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: InkWell(
                    onTap: () => _remove(photos[i]),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
