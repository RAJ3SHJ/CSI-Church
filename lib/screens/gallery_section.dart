import 'dart:async';
import 'package:flutter/material.dart';
import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import 'event_gallery_screen.dart';

const _brinjal = Color(0xFF5B2C83);

/// Landing page gallery: auto-scrolling photo strip + five album tiles.
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
          padding: const EdgeInsets.symmetric(vertical: 20),
          color: AppTheme.navyLight,
          child: Column(
            children: [
              const Text('Gallery',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _brinjal, letterSpacing: 0.5)),
              Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 14),
                  width: 48, height: 3,
                  decoration: BoxDecoration(color: _brinjal, borderRadius: BorderRadius.circular(2))),
              _Marquee(photos: all.take(30).toList()),
              const SizedBox(height: 18),
              SizedBox(
                height: 168,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    for (final k in [...GalleryService.categories.keys, 'all'])
                      _tile(context, k, all),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, String key, List<Map<String, dynamic>> all) {
    final photos = GalleryService.inCategory(all, key);
    final label = key == 'all' ? 'All' : GalleryService.categories[key]!;
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => EventGalleryScreen(title: GalleryService.labelOf(key), photos: photos))),
      child: Container(
        width: 112,
        margin: const EdgeInsets.only(right: 14, bottom: 8),
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
                      ? Container(color: Colors.white, child: const Icon(Icons.photo_library_outlined, color: _brinjal))
                      : networkPhoto(photos.first['url'].toString()),
                ),
              ),
              Container(
                width: double.infinity,
                height: 46,
                alignment: Alignment.center,
                color: _brinjal,
                child: Text(label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: 0.4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Marquee extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  const _Marquee({required this.photos});

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee> {
  final _c = ScrollController();
  Timer? _t;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (_paused || !_c.hasClients) return;
      _c.jumpTo(_c.offset + 1.0);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.photos;
    return MouseRegion(
      onEnter: (_) => _paused = true,
      onExit: (_) => _paused = false,
      child: Listener(
        onPointerDown: (_) => _paused = true,
        onPointerUp: (_) => _paused = false,
        child: SizedBox(
          height: 190,
          child: ListView.builder(
            controller: _c,
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, i) {
              final photo = p[i % p.length];
              return GestureDetector(
                onTap: () => openPhotoViewer(context, 'Gallery', p, initial: i % p.length),
                child: Container(
                  width: 260,
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: _brinjal.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 6))],
                  ),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: networkPhoto(photo['url'].toString())),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
