import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Raised when the Supabase project is configured in a way that would let a
/// user into the app without ever proving they own the email address.
class AuthConfigException extends AuthException {
  const AuthConfigException(super.message);
}

/// Wraps Supabase Auth for Scribe's sign up / sign in flow.
///
/// Email OTP is a one-time account-confirmation step at sign-up only. Once an
/// account is confirmed, sign-in is password-only: a correct password
/// immediately establishes the persisted session.
///
/// This means the password is the sole factor guarding an existing account.
/// If you ever want the OTP back as a per-login second factor, note that it
/// cannot simply be re-added to [signIn] -- `signInWithPassword` persists a
/// session as soon as it succeeds, so the password check would have to move
/// back onto a throwaway [SupabaseClient] that the persistence layer never
/// observes.
class AuthService {
  AuthService({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  SupabaseClient get _client => Supabase.instance.client;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  /// Cached across calls: the project's auth config doesn't change at runtime.
  bool? _emailConfirmationRequired;

  /// Whether the project makes users confirm their email before the account
  /// becomes usable, read from the project's public auth settings.
  ///
  /// This is the *only* thing that makes sign-up OTP a real gate. If Supabase
  /// auto-confirms (`mailer_autoconfirm`), `signUp` returns a live session and
  /// the new account is immediately usable by password -- so showing an OTP
  /// screen would guard nothing, since the user could dismiss it and sign in
  /// normally. It cannot be enforced client-side.
  ///
  /// Turn it on at: Supabase dashboard -> Authentication -> Sign In / Providers
  /// -> Email -> "Confirm email".
  Future<bool> isEmailConfirmationRequired() async {
    final cached = _emailConfirmationRequired;
    if (cached != null) return cached;

    final url = dotenv.env['SUPABASE_URL']!;
    final key = dotenv.env['SUPABASE_ANON_KEY']!;
    final res = await _http.get(
      Uri.parse('$url/auth/v1/settings'),
      headers: {'apikey': key},
    );
    if (res.statusCode != 200) {
      // Don't hand out a session on the strength of a failed probe.
      throw const AuthConfigException(
        'Could not verify sign-up security settings. Please try again.',
      );
    }

    final autoconfirm =
        (jsonDecode(res.body) as Map<String, dynamic>)['mailer_autoconfirm'] ==
        true;
    return _emailConfirmationRequired = !autoconfirm;
  }

  /// Starts sign-up. Throws [AuthException] if the email is already
  /// registered, invalid, or the password doesn't meet server requirements.
  /// On success, no session is created yet -- the account is unconfirmed
  /// until [verifySignupOtp] succeeds.
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    // Checked before creating anything, so a misconfigured project doesn't
    // leave a confirmed, password-usable account behind.
    if (!await isEmailConfirmationRequired()) {
      throw const AuthConfigException(
        'Sign-up is unavailable: this project has email confirmation turned off, '
        'so accounts would be created without verifying the address. Enable '
        '"Confirm email" in Supabase → Authentication → Sign In / Providers → Email.',
      );
    }

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
      throw const AuthException(
        'This email is already registered. Please sign in instead.',
      );
    }

    // Belt and braces: the check above should make this unreachable, but a
    // session here means the user is already through the gate. Tear it down
    // rather than let the auth stream flip the app to `authenticated`.
    if (res.session != null) {
      await _client.auth.signOut();
      throw const AuthConfigException(
        'Sign-up is unavailable: the account was created without email verification.',
      );
    }
  }

  Future<void> resendSignupOtp(String email) {
    return _client.auth.resend(type: OtpType.signup, email: email);
  }

  /// Confirms the account created by [signUp]. On success this establishes
  /// the first real, persisted session for the account.
  Future<void> verifySignupOtp({
    required String email,
    required String token,
  }) async {
    await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.signup,
    );
  }

  /// Signs in an existing, confirmed account. Throws [AuthException] on a bad
  /// password, and also if the account was never confirmed via
  /// [verifySignupOtp] ("Email not confirmed").
  ///
  /// Success persists the session, which drives [onAuthStateChange] and moves
  /// the app past the auth gate. There is no second step.
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  /// Updates the signed-in user's display name in Supabase (the `full_name`
  /// user-metadata field, the same one set at sign-up).
  Future<void> updateDisplayName(String fullName) async {
    await _client.auth.updateUser(
      UserAttributes(data: {'full_name': fullName}),
    );
  }
}
