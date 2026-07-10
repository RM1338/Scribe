import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'auth_layout.dart';
import 'otp_code_field.dart';

/// Shown only during sign-up, to confirm a newly created account. Sign-in is
/// password-only and never reaches this screen.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

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

    final ok = await auth.verifySignupOtp(code);

    if (ok && mounted) {
      // Reveal AuthGate's root route, which will have switched to AppShell
      // now that the provider's status is authenticated.
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _resend(AuthProvider auth) async {
    if (_cooldownSeconds > 0) return;
    final ok = await auth.resendSignupOtp();
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
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.appTextSecondary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: AuthLayout(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.appPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.mark_email_read_outlined,
                  color: context.appPrimary,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Enter verification code',
              style: context.pageTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We sent a 6-digit code to $email',
              style: GoogleFonts.manrope(
                color: context.appTextSecondary,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              "Can't find it? Check your spam or junk folder.",
              style: GoogleFonts.manrope(
                color: context.appTextTertiary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OtpCodeField(controller: _codeController),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                auth.errorMessage!,
                style: GoogleFonts.manrope(
                  color: context.appRecordRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
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
                  disabledBackgroundColor: context.appPrimary.withValues(
                    alpha: 0.5,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: auth.isBusy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Verify',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: (auth.isBusy || _cooldownSeconds > 0)
                    ? null
                    : () => _resend(auth),
                child: Text(
                  _cooldownSeconds > 0
                      ? 'Resend code in ${_cooldownSeconds}s'
                      : 'Resend code',
                  style: GoogleFonts.manrope(
                    color: _cooldownSeconds > 0
                        ? context.appTextTertiary
                        : context.appPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
