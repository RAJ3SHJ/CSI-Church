import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/card_service.dart';
import '../screens/card_viewer_screen.dart';

/// What the admin is about to upload: financial year, card holder, front and back photos.
class CardDraft {
  int fy;
  CardHolder? holder;
  Uint8List? front;
  Uint8List? back;
  CardDraft({int? fy, this.holder, this.front, this.back})
      : fy = fy ?? CardService.currentFyStart();

  bool get hasPhoto => front != null;
  bool get isValid => front != null && holder != null && CardService.isOpen(fy);
}

/// Asks for a name and returns it (null if cancelled). Used to add or rename a holder.
Future<String?> askHolderName(BuildContext context, {String title = 'New card holder', String initial = ''}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
            labelText: 'Card holder name *', hintText: 'e.g. Father, Mother, Wife'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final v = c.text.trim();
            if (v.isNotEmpty) Navigator.pop(ctx, v);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// Reusable upload form: FY chips (open years only), saved card holder (pick,
/// add new, rename with the pencil, view the existing card), front and back photo.
class CardDraftSection extends StatefulWidget {
  final String memberId;
  final String memberName;
  final CardDraft draft;
  final VoidCallback onChanged;
  final bool lockFyAndName;
  const CardDraftSection({
    super.key,
    required this.memberId,
    required this.memberName,
    required this.draft,
    required this.onChanged,
    this.lockFyAndName = false,
  });

  @override
  State<CardDraftSection> createState() => _CardDraftSectionState();
}

class _CardDraftSectionState extends State<CardDraftSection> {
  static const String _newKey = '__new__';
  List<CardHolder> _holders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHolders();
  }

  Future<void> _loadHolders() async {
    try {
      final h = await CardService.loadHolders(widget.memberId);
      if (!mounted) return;
      setState(() {
        _holders = h;
        _loading = false;
        // Keep the selected holder in sync with the saved list (e.g. after a rename).
        final cur = widget.draft.holder;
        if (cur != null) {
          final match = h.where((x) => x.id == cur.id);
          widget.draft.holder = match.isEmpty ? cur : match.first;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _addHolder() async {
    final name = await askHolderName(context);
    if (name == null) return;
    try {
      final h = await CardService.addHolder(widget.memberId, name);
      await _loadHolders();
      setState(() => widget.draft.holder = h);
      widget.onChanged();
    } catch (e) {
      _toast('Could not save the name: $e');
    }
  }

  Future<void> _renameHolder() async {
    final cur = widget.draft.holder;
    if (cur == null) return;
    final name = await askHolderName(context, title: 'Edit card holder name', initial: cur.name);
    if (name == null || name == cur.name) return;
    try {
      await CardService.renameHolder(widget.memberId, cur.id, name);
      await _loadHolders();
      widget.onChanged();
      _toast('Name updated. It shows the new name for all years.');
    } catch (e) {
      _toast('Could not rename: $e');
    }
  }

  Future<void> _viewExisting() async {
    final h = widget.draft.holder;
    if (h == null) {
      _toast('Choose a card holder first.');
      return;
    }
    try {
      final card = await CardService.getCard(widget.memberId, widget.draft.fy, h.id);
      if (!mounted) return;
      if (card == null) {
        _toast('No card uploaded yet for ${h.name} in ${CardService.fyLabel(widget.draft.fy)}.');
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CardViewerScreen(
            title: '${h.name} · ${CardService.fyLabel(widget.draft.fy)}',
            frontBase64: card['imageBase64'] as String,
            backBase64: card['backBase64'] as String?,
            fileName: '${widget.memberId}_${CardService.fyName(widget.draft.fy)}_${h.id}',
            allowDownload: true,
          ),
        ),
      );
    } catch (e) {
      _toast('Could not open the card: $e');
    }
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
        _holderRow(d),
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

  Widget _holderRow(CardDraft d) {
    if (widget.lockFyAndName) {
      return Row(
        children: [
          Expanded(
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Card holder name'),
              child: Text(d.holder?.name ?? ''),
            ),
          ),
          IconButton(
            onPressed: _renameHolder,
            icon: const Icon(Icons.edit_outlined, color: AppTheme.navy),
            tooltip: 'Edit name',
          ),
        ],
      );
    }
    final selected = d.holder != null && _holders.any((h) => h.id == d.holder!.id)
        ? d.holder!.id
        : null;
    return Row(
      children: [
        Expanded(
          child: _loading
              ? const LinearProgressIndicator()
              : DropdownButtonFormField<String>(
                  key: ValueKey('${d.holder?.id}_${_holders.length}_${_holders.map((h) => h.name).join()}'),
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Card holder name *'),
                  hint: Text(_holders.isEmpty ? 'Add the first card holder' : 'Choose card holder'),
                  items: [
                    for (final h in _holders)
                      DropdownMenuItem(value: h.id, child: Text(h.name)),
                    const DropdownMenuItem(value: _newKey, child: Text('+ New card holder')),
                  ],
                  onChanged: (v) {
                    if (v == _newKey) {
                      _addHolder();
                      return;
                    }
                    setState(() => d.holder = _holders.firstWhere((h) => h.id == v));
                    widget.onChanged();
                  },
                ),
        ),
        IconButton(
          onPressed: d.holder == null ? null : _renameHolder,
          icon: const Icon(Icons.edit_outlined),
          color: AppTheme.navy,
          tooltip: 'Edit name',
        ),
        IconButton(
          onPressed: d.holder == null ? null : _viewExisting,
          icon: const Icon(Icons.visibility_outlined),
          color: AppTheme.navy,
          tooltip: 'View uploaded card',
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
