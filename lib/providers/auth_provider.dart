import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import '../services/api_service.dart';
import '../services/entitlement_store.dart';
import '../models/entitlement.dart';
import '../models/user.dart';
import '../premium/premium_gate.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _loading = false;
  String? _error;
  Entitlement _entitlement = Entitlement.free;

  /// True from launch until we know whether the saved session is still good.
  /// Starts true so the very first frame is not the sign-in form.
  bool _restoring = true;
  bool _restoreFailed = false;

  User? get user => _user;
  bool get restoring => _restoring;

  /// A session is saved but the server could not be reached to confirm it.
  bool get restoreFailed => _restoreFailed;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get needsOnboarding => _user != null && !_user!.isOnboarded;

  /// Whether this account may use Premium, as last told by the backend.
  Entitlement get entitlement => _entitlement;

  /// The one place any screen should ask about Premium. Never read
  /// [entitlement] directly to gate a feature — the limits live in
  /// [PremiumGate] so they can move in one edit.
  PremiumGate get gate => PremiumGate(_entitlement);

  bool get isPremium => _entitlement.isActive;

  /// Reads the cached entitlement before the first network call, so a cold
  /// start offline does not flash the free tier at a paying user. Called
  /// from main.dart alongside [loadUser].
  Future<void> loadCachedEntitlement() async {
    if (await ApiService.getToken() == null) return;
    _entitlement = await EntitlementStore.read();
    if (_entitlement.isActive) notifyListeners();
  }

  /// Pulls `entitlement` out of an /auth/me-shaped payload and caches it.
  ///
  /// A backend that does not send the key yet yields [Entitlement.free],
  /// which is the correct reading: no entitlement on record, no Premium.
  Future<void> _applyEntitlement(Map<String, dynamic> body) async {
    final raw = body['entitlement'];
    _entitlement = raw is Map<String, dynamic>
        ? Entitlement.fromJson(raw)
        : Entitlement.free;
    await EntitlementStore.save(_entitlement);
  }

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
      await _applyEntitlement(data);
      notifyListeners();
      _adoptDeviceTimezone();
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

    final zone = await _deviceTimezone();
    final res = await ApiService.post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': password,
      // Without it every account started on UTC, so "today" rolled over at the
      // wrong hour for anyone not living on the Greenwich meridian.
      'timezone': ?zone,
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

  /// The phone's IANA zone name, or null when it cannot be read.
  Future<String?> _deviceTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return info.identifier;
    } catch (_) {
      return null;
    }
  }

  /// Accounts created before the app sent a zone sit on the server default
  /// ("UTC"). Replace that default, and only that default, with the phone's
  /// zone once, so a zone the person chose on the website is never touched.
  Future<void> _adoptDeviceTimezone() async {
    final u = _user;
    if (u == null || (u.timezone ?? 'UTC') != 'UTC') return;
    final zone = await _deviceTimezone();
    if (zone == null || zone == 'UTC') return;
    final res = await ApiService.put('/profile', {'timezone': zone});
    if (res['success'] != true) return;
    final data = res['data'];
    if (data is Map<String, dynamic> && data['user'] is Map<String, dynamic>) {
      _user = User.fromJson(data['user'] as Map<String, dynamic>);
      notifyListeners();
    }
  }

  /// Brings back a saved session on launch (and again from the retry button).
  ///
  /// Three outcomes: no token (go straight to sign-in), a good token (the
  /// app), or a token we could not verify because the network is down, which
  /// is a retry screen rather than a sign-in form: the account is fine.
  Future<void> restoreSession() async {
    _restoring = true;
    _restoreFailed = false;
    notifyListeners();

    if (await ApiService.getToken() != null) {
      await loadCachedEntitlement();
      await loadUser();
    }

    _restoring = false;
    _restoreFailed = _user == null && await ApiService.getToken() != null;
    notifyListeners();
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
        // `entitlement` sits beside `user` in the envelope, not inside it —
        // it belongs to the account, not to the profile record.
        if (data is Map<String, dynamic>) await _applyEntitlement(data);
        notifyListeners();
        await _adoptDeviceTimezone();
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
    await EntitlementStore.clear();
    _user = null;
    _entitlement = Entitlement.free;
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
      await EntitlementStore.clear();
      _user = null;
      _entitlement = Entitlement.free;
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
