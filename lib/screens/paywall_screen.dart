import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = context.appBackground;
    final Color cardColor = context.appSurface;
    final Color textPrimary = context.appTextPrimary;
    final Color textSecondary = context.appTextSecondary;
    final Color textTertiary = context.appTextTertiary;
    final Color scribeTeal = context.appPrimary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: textSecondary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            
            // 1. Sparkle Icon Accent
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scribeTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(Icons.auto_awesome_rounded, color: scribeTeal, size: 32),
              ),
            ),
            const SizedBox(height: 24),

            // 2. Title Section
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.manrope(
                  color: textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                children: [
                  const TextSpan(text: 'Upgrade to '),
                  TextSpan(
                    text: 'Scribe Pro',
                    style: TextStyle(color: scribeTeal),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Unlock the full power of your meetings',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(color: textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 40),

            // 3. Pro Plan Price Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.05)) : Border.all(color: context.appSeparator),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: scribeTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'PRO PLAN',
                      style: GoogleFonts.manrope(
                        color: scribeTeal,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$9.99',
                        style: GoogleFonts.manrope(color: textPrimary, fontSize: 48, fontWeight: FontWeight.w800, letterSpacing: -1.5),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, left: 4),
                        child: Text(
                          '/mo',
                          style: GoogleFonts.manrope(color: scribeTeal, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'MONTHLY BILLING',
                    style: GoogleFonts.manrope(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 24),
                  // Decorative graphic representation mimicking the squiggly lines in the mockup
                  Container(
                    width: double.infinity,
                    height: 100,
                    decoration: BoxDecoration(
                      color: scribeTeal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Icon(Icons.waves_rounded, color: scribeTeal.withValues(alpha: 0.5), size: 48),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // 4. Premium Features List
            Column(
              children: [
                _buildFeatureRow('Premium Whisper Model', scribeTeal, textPrimary),
                _buildFeatureRow('Unlimited Cloud Sync', scribeTeal, textPrimary),
                _buildFeatureRow('Advanced AI Themes', scribeTeal, textPrimary),
                _buildFeatureRow('Priority Support', scribeTeal, textPrimary),
              ],
            ),
            const SizedBox(height: 40),

            // 5. Upgrade Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => _simulatePayment(context, settings),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scribeTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'Upgrade Now',
                  style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 6. Restore & Terms Links
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFooterLink('Restore Purchases', textTertiary),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('•', style: GoogleFonts.manrope(color: textTertiary)),
                ),
                _buildFooterLink('Terms of Service', textTertiary),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String title, Color teal, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: teal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, color: teal, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.manrope(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text, Color color) {
    return GestureDetector(
      onTap: () {}, // No-op as requested
      child: Text(
        text,
        style: GoogleFonts.manrope(color: color, fontSize: 13),
      ),
    );
  }

  void _simulatePayment(BuildContext context, SettingsProvider settings) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    // Give it a realistic fake delay
    await Future.delayed(const Duration(seconds: 2));

    if (context.mounted) {
      Navigator.pop(context); // Dismiss loading overlay
      settings.isPro = true;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: context.appBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Welcome to Pro! 🎉',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: context.appTextPrimary),
          ),
          content: Text(
            'Your Scribe subscription is now active.',
            style: GoogleFonts.manrope(color: context.appTextSecondary),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Dismiss success dialog
                Navigator.pop(context); // Dismiss paywall screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Got it', style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }
  }
}
