import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _loading = false;
  String? _error;

  User? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get needsOnboarding => _user != null && !_user!.isOnboarded;

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// Pulls a friendly error message out of a Laravel 422 validation response.
  String _readError(Map<String, dynamic> body, String fallback) {
    final msg = body['message'];
    if (msg is String && msg.isNotEmpty) return msg;
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
      if (first is String) return first;
    }
    return fallback;
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    final res = await ApiService.post('/auth/login', {
      'email': email,
      'password': password,
      'device_name': 'mobile',
    }, auth: false);

    _loading = false;
    if (res['success'] == true) {
      final data = res['data'] as Map<String, dynamic>;
      await ApiService.setToken(data['token'].toString());
      _user = User.fromJson(data['user'] as Map<String, dynamic>);
      notifyListeners();
      return true;
    } else {
      _error = _readError(
        res['data'] is Map<String, dynamic>
            ? res['data'] as Map<String, dynamic>
            : <String, dynamic>{},
        'Login failed'.tr(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    final res = await ApiService.post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': password,
    }, auth: false);

    _loading = false;
    if (res['success'] == true) {
      final data = res['data'] as Map<String, dynamic>;
      await ApiService.setToken(data['token'].toString());
      _user = User.fromJson(data['user'] as Map<String, dynamic>);
      notifyListeners();
      return true;
    } else {
      _error = _readError(
        res['data'] is Map<String, dynamic>
            ? res['data'] as Map<String, dynamic>
            : <String, dynamic>{},
        'Registration failed'.tr(),
      );
      notifyListeners();
      return false;
    }
  }

  /// Loads the current user on app start (called from main.dart after the
  /// shared_preferences token is available).
  Future<void> loadUser() async {
    final token = await ApiService.getToken();
    if (token == null) return;

    final res = await ApiService.get('/auth/me');
    if (res['success'] == true) {
      final data = res['data'];
      Map<String, dynamic>? userJson;
      if (data is Map<String, dynamic>) {
        if (data['user'] is Map<String, dynamic>) {
          userJson = data['user'] as Map<String, dynamic>;
        } else if (data['id'] != null) {
          userJson = data;
        }
      }
      if (userJson != null) {
        _user = User.fromJson(userJson);
        notifyListeners();
      }
    } else if (res['status'] == 401) {
      // Stale token — wipe it so the login screen appears.
      await ApiService.clearToken();
    }
  }

  /// Re-fetches the current user, e.g. after onboarding completes.
  Future<void> refreshUser() => loadUser();

  /// Uploads a new profile photo. The backend crops it square and returns
  /// the updated user, so there is nothing to re-fetch afterwards.
  Future<bool> uploadAvatar(String filePath) => _applyUserResponse(
    ApiService.upload('/profile/avatar', 'avatar', filePath),
  );

  Future<bool> removeAvatar() =>
      _applyUserResponse(ApiService.delete('/profile/avatar'));

  Future<bool> _applyUserResponse(Future<Map<String, dynamic>> call) async {
    final res = await call;
    final data = res['data'];
    if (res['success'] != true) {
      _error = _readError(
        data is Map<String, dynamic> ? data : <String, dynamic>{},
        'Could not update your photo'.tr(),
      );
      notifyListeners();
      return false;
    }
    if (data is Map<String, dynamic> && data['user'] is Map<String, dynamic>) {
      _user = User.fromJson(data['user'] as Map<String, dynamic>);
    }
    _error = null;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    try {
      await ApiService.post('/auth/logout', {});
    } catch (_) {
      // Even if the logout call fails, drop local state.
    }
    await ApiService.clearToken();
    _user = null;
    notifyListeners();
  }

  /// Permanently deletes the account. The password is re-checked server
  /// side, so a wrong one comes back as a 422 and leaves the session alone.
  ///
  /// On success the token is already revoked on the backend, so the local
  /// teardown here mirrors [logout] rather than calling it — hitting
  /// /auth/logout with a dead token would only produce a 401.
  Future<bool> deleteAccount(String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    final res = await ApiService.delete(
      '/profile/account',
      body: {'password': password},
    );

    _loading = false;

    if (res['success'] == true) {
      await ApiService.clearToken();
      _user = null;
      notifyListeners();
      return true;
    }

    final data = res['data'];
    _error = _readError(
      data is Map<String, dynamic> ? data : <String, dynamic>{},
      'Could not delete your account'.tr(),
    );
    notifyListeners();
    return false;
  }
}
