import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

enum AuthStatus {
  unknown,
  unauthenticated,
  awaitingSignupOtp,
  awaitingSigninOtp,
  authenticated,
}

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

  void _onAuthStateChange(AuthState state) {
    final hasSession = state.session != null;
    switch (state.event) {
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
        _status = hasSession ? AuthStatus.authenticated : AuthStatus.unauthenticated;
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

  Future<bool> signUp({required String email, required String password, required String fullName}) {
    return _run(() async {
      await _service.signUp(email: email, password: password, fullName: fullName);
      _pendingEmail = email;
      _status = AuthStatus.awaitingSignupOtp;
    });
  }

  Future<bool> verifySignupOtp(String token) {
    return _run(() => _service.verifySignupOtp(email: _pendingEmail!, token: token));
  }

  Future<bool> resendSignupOtp() {
    return _run(() => _service.resendSignupOtp(_pendingEmail!));
  }

  Future<bool> signInStep1({required String email, required String password}) {
    return _run(() async {
      await _service.checkPasswordThenSendOtp(email: email, password: password);
      _pendingEmail = email;
      _status = AuthStatus.awaitingSigninOtp;
    });
  }

  Future<bool> verifySigninOtp(String token) {
    return _run(() => _service.verifySigninOtp(email: _pendingEmail!, token: token));
  }

  Future<bool> resendSigninOtp() {
    return _run(() => _service.resendSigninOtp(_pendingEmail!));
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
}
