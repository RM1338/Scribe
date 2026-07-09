import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps Supabase Auth for Scribe's sign up / sign in flow.
///
/// Sign-in requires BOTH a correct password AND a matching email OTP before
/// the app treats the user as logged in. To avoid ever persisting a session
/// off of just the password check, that check runs on a throwaway
/// [SupabaseClient] that Supabase Flutter's session-persistence layer never
/// subscribes to -- only a successful OTP verification touches the real,
/// persisted client. See docs/plan notes for why signIn-then-signOut on the
/// shared client would race with disk persistence instead.
class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  /// Starts sign-up. Throws [AuthException] if the email is already
  /// registered, invalid, or the password doesn't meet server requirements.
  /// On success, no session is created yet -- the account is unconfirmed
  /// until [verifySignupOtp] succeeds.
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );

    // Supabase returns 200 with an empty `identities` list (not an error) when
    // the email already belongs to a confirmed account, to avoid leaking
    // which emails are registered. Surface this as a normal error instead of
    // silently sending the user to an OTP screen for a code that never sent.
    if (res.user?.identities?.isEmpty ?? false) {
      throw const AuthException('This email is already registered. Please sign in instead.');
    }
  }

  Future<void> resendSignupOtp(String email) {
    return _client.auth.resend(type: OtpType.signup, email: email);
  }

  /// Confirms the account created by [signUp]. On success this establishes
  /// the first real, persisted session for the account.
  Future<void> verifySignupOtp({required String email, required String token}) async {
    await _client.auth.verifyOTP(email: email, token: token, type: OtpType.signup);
  }

  /// Step 1 of sign-in: verifies the password on a throwaway client (so a
  /// wrong OTP afterward can never leave a real session behind), then, only
  /// if the password was correct, sends a fresh OTP code to the email.
  Future<void> checkPasswordThenSendOtp({
    required String email,
    required String password,
  }) async {
    final scratch = SupabaseClient(
      dotenv.env['SUPABASE_URL']!,
      dotenv.env['SUPABASE_ANON_KEY']!,
    );
    try {
      await scratch.auth.signInWithPassword(email: email, password: password);
    } finally {
      try {
        await scratch.auth.signOut();
      } catch (_) {
        // Best-effort revoke of the throwaway session; nothing to react to here.
      }
      await scratch.dispose();
    }

    // Reached only if the password was correct. `shouldCreateUser: false`
    // guarantees this can never provision a new account mid-login.
    await _client.auth.signInWithOtp(email: email, shouldCreateUser: false);
  }

  Future<void> resendSigninOtp(String email) {
    return _client.auth.signInWithOtp(email: email, shouldCreateUser: false);
  }

  /// Step 2 of sign-in: verifying this is what actually creates the
  /// persisted, logged-in session.
  Future<void> verifySigninOtp({required String email, required String token}) async {
    await _client.auth.verifyOTP(email: email, token: token, type: OtpType.email);
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }
}
