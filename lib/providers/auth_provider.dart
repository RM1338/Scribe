import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

/// OTP is only ever awaited during sign-up. Sign-in is password-only, so a
/// successful [signIn] moves straight from `unauthenticated` to
/// `authenticated` via the auth state stream.
enum AuthStatus { unknown, unauthenticated, awaitingSignupOtp, authenticated }

class AuthProvider with ChangeNotifier {
  final AuthService _service;

  AuthStatus _status = AuthStatus.unknown;
  String? _pendingEmail;
  String? _errorMessage;
  bool _isBusy = false;

  AuthProvider(this._service) {
    _service.onAuthStateChange.listen(_onAuthStateChange);
  }

  AuthStatus get status => _status;
  String? get pendingEmail => _pendingEmail;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _isBusy;
  User? get currentUser => _service.currentSession?.user;

  /// The name captured at sign-up (`data: {'full_name': ...}`), if any.
  String? get signupFullName {
    final name = currentUser?.userMetadata?['full_name'] as String?;
    return (name != null && name.trim().isNotEmpty) ? name.trim() : null;
  }

  String? get signupEmail => currentUser?.email;

  void _onAuthStateChange(AuthState state) {
    final hasSession = state.session != null;
    switch (state.event) {
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
        _status = hasSession
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;
        notifyListeners();
        break;
      case AuthChangeEvent.signedOut:
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        break;
      default:
        break;
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _run(() async {
      await _service.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );
      _pendingEmail = email;
      _status = AuthStatus.awaitingSignupOtp;
    });
  }

  Future<bool> verifySignupOtp(String token) {
    return _run(
      () => _service.verifySignupOtp(email: _pendingEmail!, token: token),
    );
  }

  Future<bool> resendSignupOtp() {
    return _run(() => _service.resendSignupOtp(_pendingEmail!));
  }

  /// Password-only. On success the auth state stream flips [status] to
  /// [AuthStatus.authenticated], so callers don't navigate anywhere.
  Future<bool> signIn({required String email, required String password}) {
    return _run(() => _service.signIn(email: email, password: password));
  }

  void cancelPendingAuth() {
    _pendingEmail = null;
    _errorMessage = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> signOut() {
    return _service.signOut();
  }

  /// Persists a new display name to Supabase and refreshes local state so the
  /// avatar/greeting update. Returns false if the update failed.
  Future<bool> updateDisplayName(String fullName) async {
    try {
      await _service.updateDisplayName(fullName);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
