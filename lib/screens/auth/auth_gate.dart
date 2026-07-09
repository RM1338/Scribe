import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../navigation/app_shell.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'sign_in_screen.dart';

/// Root-level switch between the auth flow and the app itself.
/// Intermediate OTP steps are reached via explicit push navigation from
/// [SignInScreen]/[SignUpScreen], not handled here -- this only decides
/// between "show the sign-in flow" and "show the app".
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;

    if (status == AuthStatus.authenticated) {
      return AppShell(key: AppShell.shellKey);
    }

    if (status == AuthStatus.unknown) {
      return Scaffold(
        backgroundColor: context.appBackground,
        body: Center(
          child: CircularProgressIndicator(color: context.appPrimary),
        ),
      );
    }

    return const SignInScreen();
  }
}
