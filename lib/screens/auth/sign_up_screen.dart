import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'auth_layout.dart';
import 'auth_text_field.dart';
import 'otp_verification_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  String? _localError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    FocusScope.of(context).unfocus();
    setState(() => _localError = null);

    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _localError = 'Please fill in all fields.');
      return;
    }
    if (_passwordController.text.length < 8) {
      setState(() => _localError = 'Password must be at least 8 characters.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _localError = 'Passwords do not match.');
      return;
    }

    final ok = await auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _nameController.text.trim(),
    );
    if (ok && mounted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const OtpVerificationScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final error = _localError ?? auth.errorMessage;

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
            Text(
              'Create your account',
              style: context.pageTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "We'll send a code to verify your email",
              style: GoogleFonts.manrope(
                color: context.appTextSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            AuthTextField(
              controller: _nameController,
              hintText: 'Full name',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _emailController,
              hintText: 'Email',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _passwordController,
              hintText: 'Password (min. 8 characters)',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: context.appTextSecondary,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _confirmController,
              hintText: 'Confirm password',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              Text(
                error,
                style: GoogleFonts.manrope(
                  color: context.appRecordRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: auth.isBusy ? null : () => _submit(auth),
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
                        'Create Account',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
