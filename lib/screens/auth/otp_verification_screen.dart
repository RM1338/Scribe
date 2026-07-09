import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

enum OtpMode { signup, signin }

class OtpVerificationScreen extends StatefulWidget {
  final OtpMode mode;

  const OtpVerificationScreen({super.key, required this.mode});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void dispose() {
    _codeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldownSeconds <= 1) {
        t.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  Future<void> _verify(AuthProvider auth) async {
    FocusScope.of(context).unfocus();
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final ok = widget.mode == OtpMode.signup
        ? await auth.verifySignupOtp(code)
        : await auth.verifySigninOtp(code);

    if (ok && mounted) {
      // Reveal AuthGate's root route, which will have switched to AppShell
      // now that the provider's status is authenticated.
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _resend(AuthProvider auth) async {
    if (_cooldownSeconds > 0) return;
    final ok = widget.mode == OtpMode.signup
        ? await auth.resendSignupOtp()
        : await auth.resendSigninOtp();
    if (ok) _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final email = auth.pendingEmail ?? '';

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.appTextSecondary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: context.appPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.mark_email_read_outlined, color: context.appPrimary, size: 32),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Enter verification code',
                style: GoogleFonts.manrope(
                  color: context.appTextPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to $email',
                style: GoogleFonts.manrope(color: context.appTextSecondary, fontSize: 15),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.appSeparator, width: 1.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: GoogleFonts.manrope(
                    color: context.appTextPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle: GoogleFonts.manrope(
                      color: context.appTextSecondary.withValues(alpha: 0.3),
                      letterSpacing: 8,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  auth.errorMessage!,
                  style: GoogleFonts.manrope(color: context.appRecordRed, fontSize: 13, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: auth.isBusy ? null : () => _verify(auth),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.appPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: context.appPrimary.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: auth.isBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          'Verify',
                          style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: (auth.isBusy || _cooldownSeconds > 0) ? null : () => _resend(auth),
                  child: Text(
                    _cooldownSeconds > 0 ? 'Resend code in ${_cooldownSeconds}s' : 'Resend code',
                    style: GoogleFonts.manrope(
                      color: _cooldownSeconds > 0 ? context.appTextTertiary : context.appPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
