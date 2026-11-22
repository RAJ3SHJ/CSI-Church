import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/download_stub.dart'
    if (dart.library.js_interop) '../services/download_web.dart';

/// Full-screen, zoomable view of a card. If the card has a back side it can be
/// flipped (tap the card or the Flip button). Download only when allowed (admins).
class CardViewerScreen extends StatefulWidget {
  final String title;
  final String frontBase64;
  final String? backBase64;
  final String fileName; // without extension
  final bool allowDownload;
  const CardViewerScreen({
    super.key,
    required this.title,
    required this.frontBase64,
    this.backBase64,
    required this.fileName,
    this.allowDownload = false,
  });

  @override
  State<CardViewerScreen> createState() => _CardViewerScreenState();
}

class _CardViewerScreenState extends State<CardViewerScreen> {
  bool _showBack = false;

  bool get _hasBack => (widget.backBase64 ?? '').isNotEmpty;

  void _flip() {
    if (_hasBack) setState(() => _showBack = !_showBack);
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List front = base64Decode(widget.frontBase64);
    final Uint8List? back = _hasBack ? base64Decode(widget.backBase64!) : null;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.white,
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        actions: [
          if (widget.allowDownload)
            TextButton.icon(
              onPressed: () {
                final showBack = _showBack && back != null;
                final ok = downloadBytes(showBack ? back : front,
                    '${widget.fileName}${showBack ? '_back' : '_front'}.jpg');
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Download is available in the web version.')));
                }
              },
              icon: const Icon(Icons.download_rounded, color: AppTheme.white),
              label: Text(_showBack ? 'Download back' : 'Download',
                  style: const TextStyle(color: AppTheme.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 6,
                child: GestureDetector(
                  onTap: _flip,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: _showBack ? math.pi : 0),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeInOut,
                    builder: (context, angle, _) {
                      final isBackVisible = angle > math.pi / 2;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle),
                        child: isBackVisible
                            ? Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.rotationY(math.pi),
                                child: Image.memory(back ?? front, fit: BoxFit.contain),
                              )
                            : Image.memory(front, fit: BoxFit.contain),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (_hasBack)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _flip,
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.navy),
                    icon: const Icon(Icons.flip_rounded),
                    label: Text(_showBack ? 'Show front' : 'Flip to see back'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
