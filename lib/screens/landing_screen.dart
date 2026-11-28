import '../services/event_photo_service.dart';
import 'event_gallery_screen.dart';
import '../services/member_session.dart';
import 'phone_login_screen.dart';
import 'gallery_section.dart';
import 'history_screen.dart';
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
                _twoColumns(),
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

  static const Color _deep = Color(0xFF2A0F4D);

  Widget _twoColumns() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5B2C83), Color(0xFF3A1767), _deep],
        ),
      ),
      child: Stack(
        children: [
          // church picture fading into the background, top right
          Positioned(
            top: 0,
            right: 0,
            child: ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [Colors.white, Colors.transparent],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: Image.asset('assets/images/church.jpg', width: 190, fit: BoxFit.fitWidth),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _column('Events', 'events', Icons.event_outlined, newestFirst: false),
                const SizedBox(height: 22),
                _column('Upcoming Events', 'announcements', Icons.event_available_outlined, newestFirst: true),
                const SizedBox(height: 22),
                _column('Announcements', 'notices', Icons.campaign_outlined, newestFirst: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String heading, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Text(heading,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: 90,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(colors: [Color(0xFFB98CE8), Color(0x00B98CE8)]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _column(String heading, String collection, IconData defaultIcon, {required bool newestFirst}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(heading, defaultIcon),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection(collection).snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Text('Could not load right now.',
                  style: TextStyle(fontSize: 11, color: Colors.white70));
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
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
                return _card(context, title, desc, venue, EventPhotoService.photosOf(m), defaultIcon);
              }).toList();
            if (cards.isEmpty) return const SizedBox.shrink();
            return Column(children: cards);
          },
        ),
      ],
    );
  }

  IconData _iconFor(String title, IconData fallback) {
    final t = title.toLowerCase();
    bool has(List<String> k) => k.any(t.contains);
    if (has(['christmas', 'carol', 'nativity', 'advent'])) return Icons.auto_awesome;
    if (has(['sunday school', 'school', 'kids', 'children', 'vbs'])) return Icons.menu_book_outlined;
    if (has(['women', 'ladies', 'mother'])) return Icons.face_3_outlined;
    if (has(['youth', 'young', 'fellowship', 'group'])) return Icons.groups_outlined;
    if (has(['prayer', 'intercession'])) return Icons.volunteer_activism_outlined;
    if (has(['choir', 'music', 'song'])) return Icons.music_note_outlined;
    if (has(['service', 'worship', 'mass', 'communion', 'church'])) return Icons.church_outlined;
    return fallback;
  }

  Widget _card(BuildContext context, String title, String desc, String venue,
      List<Map<String, dynamic>> photos, IconData fallbackIcon) {
    const ink = Color(0xFF4A1A7A);
    Widget line(IconData i, String text) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(i, size: 15, color: ink),
              const SizedBox(width: 6),
              Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF2B1B3F), height: 1.25)),
              ),
            ],
          ),
        );
    final divider = Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 12), color: ink.withOpacity(0.25));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: photos.isEmpty ? null : () => openPhotoViewer(context, title, photos),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 84),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F1FD), Color(0xFFDCCBF2)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.8), width: 1),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 8)),
            BoxShadow(color: Color(0x33FFFFFF), blurRadius: 4, offset: Offset(-1, -1)),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Color(0xFFE6D8F6)]),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))],
                  ),
                  child: Icon(_iconFor(title, fallbackIcon), size: 30, color: ink),
                ),
              ),
              divider,
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink)),
                    if (desc.isNotEmpty) line(Icons.schedule, desc),
                    if (venue.isNotEmpty) line(Icons.location_on, 'Venue: $venue'),
                  ],
                ),
              ),
              if (photos.isNotEmpty) ...[
                divider,
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(width: 52, height: 52, child: networkPhoto(photos.first['url'].toString())),
                      ),
                      const SizedBox(width: 8),
                      Text('${photos.length} photo${photos.length == 1 ? '' : 's'} ›',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
                // Our History link (centered, text only)
                Align(
                  alignment: Alignment.center,
                  child: InkWell(
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
                    child: const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text('Our History',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white)),
                    ),
                  ),
                ),
                // Pastors side by side
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _pastor('assets/images/pastor.jpg', 'Rev. M. George Ebenezer Raju',
                          const ['Presbyter-in-Charge & Chairman, MDCC']),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _pastor('assets/images/pastor2.jpg', 'Rev. B. Sudheer Kumar',
                          const ['Asst. Presbyter Sangareddy']),
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
                width: 52, height: 52, fit: BoxFit.cover, alignment: Alignment.topCenter),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600, height: 1.3)),
              for (final l in lines)
                Text(l, style: const TextStyle(fontSize: 10, color: Colors.white, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}
