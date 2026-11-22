import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/card_service.dart';

/// What the admin is about to upload: financial year, card name, front and back photos.
class CardDraft {
  int fy;
  String name;
  Uint8List? front;
  Uint8List? back;
  CardDraft({int? fy, this.name = '', this.front, this.back})
      : fy = fy ?? CardService.currentFyStart();

  bool get hasPhoto => front != null;
  bool get isValid => front != null && name.trim().isNotEmpty && CardService.isOpen(fy);
}

/// Reusable upload form: FY chips (open years only), card name, front and back photo.
class CardDraftSection extends StatefulWidget {
  final CardDraft draft;
  final VoidCallback onChanged;
  final bool lockFyAndName;
  const CardDraftSection({
    super.key,
    required this.draft,
    required this.onChanged,
    this.lockFyAndName = false,
  });

  @override
  State<CardDraftSection> createState() => _CardDraftSectionState();
}

class _CardDraftSectionState extends State<CardDraftSection> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.draft.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// Asks whether to take a photo with the camera or choose one from the gallery/files.
  Future<void> _choose(bool front) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppTheme.navy),
              title: const Text('Take a photo with the camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.navy),
              title: const Text('Upload from gallery / files'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pick(front, source);
  }

  Future<void> _pick(bool front, ImageSource source) async {
    try {
      // Resized and compressed by the picker so the stored file stays small.
      final XFile? picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 2000,
        imageQuality: 70,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 450 * 1024) {
        _toast('Photo is too large even after shrinking. Please retake it closer or in better light.');
        return;
      }
      setState(() {
        if (front) {
          widget.draft.front = bytes;
        } else {
          widget.draft.back = bytes;
        }
      });
      widget.onChanged();
    } catch (e) {
      _toast('Could not pick the photo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final cur = CardService.currentFyStart();
    final years = widget.lockFyAndName ? [d.fy] : [cur, cur + 1];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final fy in years)
              GestureDetector(
                onTap: widget.lockFyAndName
                    ? null
                    : () {
                        setState(() => d.fy = fy);
                        widget.onChanged();
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: d.fy == fy ? AppTheme.navy : AppTheme.navyLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(CardService.fyLabel(fy),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: d.fy == fy ? AppTheme.white : AppTheme.navy)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Past financial years are closed.',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          enabled: !widget.lockFyAndName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Card name *',
            hintText: 'e.g. Father, Mother, Wife',
          ),
          onChanged: (v) {
            d.name = v;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _side('Front *', d.front, () => _choose(true),
                onRemove: d.front == null ? null : () {
                  setState(() => d.front = null);
                  widget.onChanged();
                })),
            const SizedBox(width: 10),
            Expanded(child: _side('Back (optional)', d.back, () => _choose(false),
                onRemove: d.back == null ? null : () {
                  setState(() => d.back = null);
                  widget.onChanged();
                })),
          ],
        ),
      ],
    );
  }

  Widget _side(String label, Uint8List? bytes, VoidCallback onPick, {VoidCallback? onRemove}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.navy)),
        const SizedBox(height: 6),
        Container(
          height: 110,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.navyLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: bytes == null
              ? const Center(child: Icon(Icons.image_outlined, color: AppTheme.textSecondary))
              : Image.memory(bytes, fit: BoxFit.cover, alignment: Alignment.topCenter),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: Text(bytes == null ? 'Add photo' : 'Change'),
            ),
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Remove',
              ),
          ],
        ),
      ],
    );
  }
}
