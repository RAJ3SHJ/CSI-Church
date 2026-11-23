import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Photo for display. WebHtmlElementStrategy lets the browser show Firebase
/// Storage pictures without any extra bucket (CORS) setup.
Widget networkPhoto(String url, {BoxFit fit = BoxFit.cover}) => Image.network(
      url,
      fit: fit,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined, color: AppTheme.textSecondary)),
      loadingBuilder: (c, child, p) => p == null
          ? child
          : const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
    );

/// Public gallery: grid of photos, tap one to see it full screen and swipe.
class EventGalleryScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> photos;
  const EventGalleryScreen({super.key, required this.title, required this.photos});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.white,
        title: Text(title.isEmpty ? 'Photos' : title, style: const TextStyle(fontSize: 18)),
      ),
      body: photos.isEmpty
          ? const Center(child: Text('No photos yet.'))
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: photos.length,
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => openPhotoViewer(context, title, photos, initial: i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: networkPhoto(photos[i]['url'].toString()),
                ),
              ),
            ),
    );
  }
}

class _PhotoPager extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> photos;
  final int initial;
  const _PhotoPager({this.title = '', required this.photos, required this.initial});

  @override
  State<_PhotoPager> createState() => _PhotoPagerState();
}

class _PhotoPagerState extends State<_PhotoPager> {
  late final PageController _page = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  void _go(int delta) {
    final n = (_index + delta).clamp(0, widget.photos.length - 1);
    _page.animateToPage(n, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Widget _arrow(IconData icon, bool enabled, VoidCallback onTap) => Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, color: enabled ? Colors.white : Colors.white24, size: 30),
          onPressed: enabled ? onTap : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final n = widget.photos.length;
    return Focus(
      autofocus: true,
      onKeyEvent: (node, e) {
        if (e is KeyDownEvent) {
          if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
            _go(1);
            return KeyEventResult.handled;
          }
          if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _go(-1);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.title.isEmpty ? 'Photos' : widget.title,
              style: const TextStyle(fontSize: 16)),
          actions: [
            Center(
                child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text('${_index + 1} / $n', style: const TextStyle(fontSize: 14)),
            )),
            IconButton(
              tooltip: 'All photos',
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          EventGalleryScreen(title: widget.title, photos: widget.photos))),
            ),
          ],
        ),
        body: Stack(
          children: [
            PageView.builder(
              controller: _page,
              itemCount: n,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => InteractiveViewer(
                child: Center(
                    child: networkPhoto(widget.photos[i]['url'].toString(), fit: BoxFit.contain)),
              ),
            ),
            if (n > 1) ...[
              Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _arrow(Icons.chevron_left, _index > 0, () => _go(-1)))),
              Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                      child: _arrow(Icons.chevron_right, _index < n - 1, () => _go(1)))),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens the full-screen viewer (with next/previous arrows) at the first photo.
void openPhotoViewer(BuildContext context, String title, List<Map<String, dynamic>> photos,
    {int initial = 0}) {
  Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => _PhotoPager(title: title, photos: photos, initial: initial)));
}

/// Small "N photos" chip that opens the gallery. Shows nothing without photos.
class PhotosChip extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> photos;
  const PhotosChip({super.key, required this.title, required this.photos});

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () => openPhotoViewer(context, title, photos),
        borderRadius: BorderRadius.circular(10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 56, height: 56, child: networkPhoto(photos.first['url'].toString())),
            ),
            const SizedBox(width: 8),
            Text('${photos.length} photo${photos.length == 1 ? '' : 's'} ›',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.navy)),
          ],
        ),
      ),
    );
  }
}
