import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _userModel;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get userModel => _userModel;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      _status = AuthStatus.unauthenticated;
      _userModel = null;
    } else {
      _userModel = await _authService.getUserModel(user.uid);
      _status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _userModel = await _authService.registerWithEmail(
        email: email,
        password: password,
        name: name,
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _userModel = await _authService.loginWithEmail(
          email: email, password: password);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _userModel = await _authService.signInWithGoogle();
      if (_userModel != null) {
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
      return _userModel != null;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _userModel = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void updateUserModel(UserModel model) {
    _userModel = model;
    notifyListeners();
  }

  Future<bool> updateName(String name) async {
    if (_userModel == null) return false;
    try {
      await _authService.updateName(_userModel!.uid, name);
      _userModel = _userModel!.copyWith(name: name);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateNotificationSettings({
    required bool sessionReminders,
    required bool dailySummary,
    required bool streakAlerts,
  }) async {
    if (_userModel == null) return false;
    try {
      final updatedSettings = Map<String, dynamic>.from(_userModel!.settings);
      updatedSettings['sessionReminders'] = sessionReminders;
      updatedSettings['dailySummary'] = dailySummary;
      updatedSettings['streakAlerts'] = streakAlerts;

      await _authService.updateSettings(_userModel!.uid, updatedSettings);
      _userModel = _userModel!.copyWith(settings: updatedSettings);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
