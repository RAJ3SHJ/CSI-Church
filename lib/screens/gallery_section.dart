import 'dart:async';
import 'package:flutter/material.dart';
import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import 'event_gallery_screen.dart';

const _brinjal = Color(0xFF5B2C83);

const _icons = <String, IconData>{
  'youth': Icons.groups_outlined,
  'women': Icons.diversity_1_outlined,
  'sunday': Icons.child_care_outlined,
  'church': Icons.church_outlined,
};

/// Landing page gallery: four album tiles. Each tile slides through its own photos.
class GallerySection extends StatelessWidget {
  const GallerySection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: GalleryService.col.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final all = GalleryService.parse(snap.data!);
        if (all.isEmpty) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: AppTheme.navyLight,
          padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
          child: SizedBox(
            height: 190,
            child: Row(
              children: [
                for (var i = 0; i < GalleryService.categories.length; i++)
                  Expanded(child: _tile(context, GalleryService.categories.keys.elementAt(i), all, i)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, String key, List<Map<String, dynamic>> all, int index) {
    final photos = GalleryService.inCategory(all, key);
    final label = GalleryService.categories[key]!;
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => EventGalleryScreen(title: GalleryService.labelOf(key), photos: photos))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: _brinjal.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 6)),
            const BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: photos.isEmpty
                      ? Container(color: Colors.white, child: Icon(_icons[key], color: _brinjal, size: 36))
                      : _Slides(photos: photos, delayMs: index * 700),
                ),
              ),
              Container(
                width: double.infinity,
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                color: _brinjal,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_icons[key], color: Colors.white, size: 16),
                    const SizedBox(height: 2),
                    Text(label.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w700, height: 1.15)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades through an album's photos on its own.
class _Slides extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final int delayMs;
  const _Slides({required this.photos, required this.delayMs});

  @override
  State<_Slides> createState() => _SlidesState();
}

class _SlidesState extends State<_Slides> {
  Timer? _t;
  Timer? _start;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _start = Timer(Duration(milliseconds: widget.delayMs), () {
      _t = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted && widget.photos.length > 1) {
          setState(() => _i = (_i + 1) % widget.photos.length);
        }
      });
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.photos[_i % widget.photos.length];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      child: SizedBox.expand(
        key: ValueKey(p['id'] ?? _i),
        child: networkPhoto(p['url'].toString()),
      ),
    );
  }
}
