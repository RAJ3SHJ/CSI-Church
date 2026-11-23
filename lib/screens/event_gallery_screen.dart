import 'package:flutter/material.dart';
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
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _PhotoPager(photos: photos, initial: i))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: networkPhoto(photos[i]['url'].toString()),
                ),
              ),
            ),
    );
  }
}

class _PhotoPager extends StatelessWidget {
  final List<Map<String, dynamic>> photos;
  final int initial;
  const _PhotoPager({required this.photos, required this.initial});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: PageView.builder(
        controller: PageController(initialPage: initial),
        itemCount: photos.length,
        itemBuilder: (context, i) => InteractiveViewer(
          child: Center(child: networkPhoto(photos[i]['url'].toString(), fit: BoxFit.contain)),
        ),
      ),
    );
  }
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
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => EventGalleryScreen(title: title, photos: photos))),
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
