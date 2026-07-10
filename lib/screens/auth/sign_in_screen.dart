import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'auth_layout.dart';
import 'auth_text_field.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    FocusScope.of(context).unfocus();
    // No navigation on success: a persisted session flips AuthProvider.status
    // to authenticated, and AuthGate swaps this screen for the app.
    await auth.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
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
                  Icons.mic_rounded,
                  color: context.appPrimary,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome back',
              style: context.pageTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to continue to Scribe',
              style: GoogleFonts.manrope(
                color: context.appTextSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            AuthTextField(
              controller: _emailController,
              hintText: 'Email',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _passwordController,
              hintText: 'Password',
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
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                auth.errorMessage!,
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
                        'Sign In',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: GoogleFonts.manrope(
                    color: context.appTextSecondary,
                    fontSize: 14,
                  ),
                ),
                GestureDetector(
                  onTap: auth.isBusy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SignUpScreen(),
                          ),
                        ),
                  child: Text(
                    'Sign Up',
                    style: GoogleFonts.manrope(
                      color: context.appPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
