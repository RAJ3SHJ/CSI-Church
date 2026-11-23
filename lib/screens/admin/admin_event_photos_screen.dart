import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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


/// Holds the photo changes made inside an Add/Edit event form. Nothing is
/// uploaded until the admin taps Save.
class EventPhotosController {
  final List<Uint8List> pending = [];
  final List<Map<String, dynamic>> removed = [];

  bool get hasChanges => pending.isNotEmpty || removed.isNotEmpty;

  Future<void> applyTo(DocumentReference<Map<String, dynamic>> ref) async {
    for (final p in removed) {
      await EventPhotoService.remove(ref, p);
    }
    var i = 0;
    for (final b in pending) {
      await EventPhotoService.uploadBytes(ref, b, i++);
    }
  }
}

/// "Photos" section for the Add/Edit event dialogs (placed below Venue).
class EventPhotosField extends StatefulWidget {
  final EventPhotosController controller;
  final List<Map<String, dynamic>> existing;
  const EventPhotosField({super.key, required this.controller, required this.existing});

  @override
  State<EventPhotosField> createState() => _EventPhotosFieldState();
}

class _EventPhotosFieldState extends State<EventPhotosField> {
  Future<void> _add() async {
    final files = await ImagePicker()
        .pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 78);
    for (final f in files) {
      widget.controller.pending.add(await f.readAsBytes());
    }
    if (mounted) setState(() {});
  }

  Widget _thumb(Widget image, VoidCallback onRemove) => Stack(
        children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 64, height: 64, child: image)),
          Positioned(
            top: 2,
            right: 2,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final saved = widget.existing.where((p) => !c.removed.contains(p)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Photos',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.navy)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in saved)
              _thumb(networkPhoto(p['url'].toString()), () => setState(() => c.removed.add(p))),
            for (var i = 0; i < c.pending.length; i++)
              _thumb(Image.memory(c.pending[i], fit: BoxFit.cover),
                  () => setState(() => c.pending.removeAt(i))),
            InkWell(
              onTap: _add,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.navy),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.add_photo_alternate_outlined, color: AppTheme.navy),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
