import '../services/event_photo_service.dart';
import 'event_gallery_screen.dart';
import '../services/member_session.dart';
import 'phone_login_screen.dart';
import 'gallery_section.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'contact_us_screen.dart';
import 'admin/admin_login_screen.dart';

/// Public landing page: church photo, pastor details, Events and Upcoming Events
/// (managed by admins) in two columns, and Member / Admin login links.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  static const Color _lavender = Color(0xFF5B2C83);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            child: Column(
              children: [
                _header(context),
                const GallerySection(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: _twoColumns(),
                ),
                // Bottom band: Contact Us + logins with icons
                Container(
                  width: double.infinity,
                  color: _lavender,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _bottomBtn(context, Icons.contact_phone_outlined, 'Contact Us', () => const ContactUsScreen()),
                      _bottomBtn(context, Icons.person_outline, 'Member Login',
                          () => kPhoneLoginEnabled ? const PhoneLoginScreen() : const LoginScreen()),
                      _bottomBtn(context, Icons.admin_panel_settings_outlined, 'Admin Login', () => const AdminLoginScreen()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBtn(BuildContext context, IconData icon, String label, Widget Function() page) =>
      InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _boxed(Widget child) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: _lavender, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );

  Widget _twoColumns() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _boxed(_column('Events', 'events', newestFirst: false)),
        const SizedBox(height: 16),
        _boxed(_column('Upcoming Events', 'announcements', newestFirst: true)),
        const SizedBox(height: 16),
        _boxed(_column('Announcements', 'notices', newestFirst: true)),
      ],
    );
  }

  Widget _column(String heading, String collection, {required bool newestFirst}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(heading,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.navy)),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection(collection).snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Text('Could not load right now.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary));
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            final docs = [...snap.data!.docs]..sort((a, b) {
                final ta = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                final tb = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                if (ta == null && tb == null) return 0;
                if (ta == null) return 1;
                if (tb == null) return -1;
                return newestFirst ? tb.compareTo(ta) : ta.compareTo(tb);
              });
            final cards = docs.map((d) {
                final m = d.data() as Map<String, dynamic>;
                final title = (m['title'] ?? '').toString().trim();
                final desc = (m['description'] ?? '').toString().trim();
                final venue = (m['location'] ?? '').toString().trim();
                if (title.isEmpty && desc.isEmpty && venue.isEmpty) return const SizedBox.shrink();
                return _card(context, title, desc, venue, EventPhotoService.photosOf(m));
              }).toList();
            if (cards.isEmpty) return const SizedBox.shrink();
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.only(bottom: 10),
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cards),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _card(BuildContext context, String title, String desc, String venue,
      List<Map<String, dynamic>> photos) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: photos.isEmpty
          ? null
          : () => openPhotoViewer(context, title, photos),
      child: Container(
      width: 240,
      margin: const EdgeInsets.only(right: 14, bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _lavender.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: _lavender.withOpacity(0.30), blurRadius: 12, offset: const Offset(0, 6)),
          const BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.navy)),
          if (desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(desc,
                  style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.3)),
            ),
          if (venue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('Venue: $venue',
                  style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.3)),
            ),
          PhotosChip(title: title, photos: photos),
        ],
      ),
    ));
  }

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _lavender,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header banner: full width, whole picture visible (no crop)
          SizedBox(
            width: double.infinity,
            child: Image.asset('assets/images/banner.jpg', fit: BoxFit.fitWidth),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Church picture on the left, pastors stacked on the right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Image.asset('assets/images/church.jpg', fit: BoxFit.fitWidth),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _pastor('assets/images/pastor.jpg', 'Rev. M. George Ebenezer Raju',
                              const ['Presbyter-in-Charge & Chairman, MDCC']),
                          const SizedBox(height: 12),
                          _pastor('assets/images/pastor2.jpg', 'Rev. B. Sudheer Kumar',
                              const ['Asst. Presbyter Sangareddy']),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pastor(String asset, String name, List<String> lines) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: ClipOval(
            child: Image.asset(asset,
                width: 56, height: 56, fit: BoxFit.cover, alignment: Alignment.topCenter),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600, height: 1.3)),
              for (final l in lines)
                Text(l, style: const TextStyle(fontSize: 11, color: Colors.white, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}
