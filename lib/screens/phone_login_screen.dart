import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/member_session.dart';
import '../theme/app_theme.dart';
import 'member/dashboard_screen.dart';
import 'admin/admin_login_screen.dart';

/// Member login with phone number + OTP. Numbers are verified by an admin
/// first; only verified numbers can sign in.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  ConfirmationResult? _confirmation;
  String? _e164;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final e164 = MemberSession.toE164(_phone.text);
    if (e164 == null) {
      setState(() => _error = 'Enter your 10-digit mobile number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Check with the church records first, so no SMS is wasted.
      final snap = await FirebaseFirestore.instance
          .collection('members')
          .where('phoneE164', isEqualTo: e164)
          .get();
      if (snap.docs.isEmpty) {
        setState(() {
          _busy = false;
          _error = 'This is a different phone number from the one registered '
              'with the church. Please contact the church admin.';
        });
        return;
      }
      final ok = await MemberSession.membersForPhone(e164);
      if (ok.isEmpty) {
        setState(() {
          _busy = false;
          _error = 'Your phone number has not been verified yet, or your '
              'membership is inactive. Please contact the church admin.';
        });
        return;
      }
      final result = await FirebaseAuth.instance.signInWithPhoneNumber(e164);
      setState(() {
        _confirmation = result;
        _e164 = e164;
        _busy = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _busy = false;
        _error = e.code == 'too-many-requests'
            ? 'Too many attempts. Please try again after some time.'
            : e.code == 'invalid-phone-number'
                ? 'That phone number is not valid.'
                : 'Could not send the OTP (${e.code}). Please try again.';
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otp.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _confirmation!.confirm(code);
      final members = await MemberSession.membersForPhone(_e164!);
      if (members.isEmpty) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _busy = false;
          _confirmation = null;
          _error = 'This phone number is not verified. Please contact the church admin.';
        });
        return;
      }
      var chosen = members.first;
      if (members.length > 1 && mounted) {
        final pick = await _chooseMember(members);
        if (pick == null) {
          await FirebaseAuth.instance.signOut();
          setState(() {
            _busy = false;
            _confirmation = null;
          });
          return;
        }
        chosen = pick;
      }
      final memberId = (chosen.data()['memberId'] ?? '').toString();
      MemberSession.chosenMemberId = memberId;
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreen(memberId: memberId)),
        (r) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _busy = false;
        _error = e.code == 'invalid-verification-code'
            ? 'Wrong OTP. Please check and try again.'
            : e.code == 'session-expired' || e.code == 'code-expired'
                ? 'The OTP has expired. Please go back and request a new one.'
                : 'Could not verify the OTP (${e.code}).';
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _chooseMember(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> members) {
    return showDialog<QueryDocumentSnapshot<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false,
      builder: (c) => SimpleDialog(
        title: const Text('Who is signing in?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.navy)),
        children: [
          for (final m in members)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, m),
              child: Text('${m.data()['name'] ?? ''}  ·  ${m.data()['memberId'] ?? ''}',
                  style: const TextStyle(fontSize: 15)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final otpStep = _confirmation != null;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            color: AppTheme.navy,
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12, bottom: 20, left: 8, right: 24),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CSI Church',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.white)),
                      Text('Sangareddy Pastorate', style: TextStyle(fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otpStep
                        ? 'Enter the 6-digit OTP sent to +91 ${_e164!.substring(3)}'
                        : 'Sign in with your registered mobile number',
                    style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  if (!otpStep) ...[
                    const Text('Mobile Number',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.navy)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 2),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      onSubmitted: (_) => _busy ? null : _sendOtp(),
                      decoration: const InputDecoration(
                        prefixText: '+91  ',
                        prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.navy, size: 22),
                        hintText: '10-digit number',
                      ),
                    ),
                  ] else ...[
                    const Text('OTP',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.navy)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _otp,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 8),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onSubmitted: (_) => _busy ? null : _verifyOtp(),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.sms_outlined, color: AppTheme.navy, size: 22),
                        hintText: '------',
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                          color: AppTheme.errorLight, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(color: AppTheme.error, fontSize: 13))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _busy ? null : (otpStep ? _verifyOtp : _sendOtp),
                    child: _busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(color: AppTheme.white, strokeWidth: 2.5))
                        : Text(otpStep ? 'Verify & Sign In' : 'Send OTP'),
                  ),
                  if (otpStep)
                    Center(
                      child: TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _confirmation = null;
                                  _otp.clear();
                                  _error = null;
                                }),
                        child: const Text('Change number / resend OTP'),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'Your number must be registered and verified by the\nchurch admin. Contact the church office for help.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.65),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => const AdminLoginScreen())),
                      child: const Text('Admin Sign In →',
                          style: TextStyle(
                              color: AppTheme.navy, fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
