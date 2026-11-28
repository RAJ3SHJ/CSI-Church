import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// "Our History": the church history picture, zoomable.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.white,
        title: const Text('Our History', style: TextStyle(fontSize: 18)),
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(child: Image.asset('assets/images/history.jpg', fit: BoxFit.contain)),
      ),
    );
  }
}
