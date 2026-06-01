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

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    final res = await ApiService.post('/auth/login', {
      'email': email,
      'password': password,
    }, auth: false);

    _loading = false;
    if (res['success']) {
      await ApiService.setToken(res['data']['token']);
      _user = User.fromJson(res['data']['user']);
      notifyListeners();
      return true;
    } else {
      _error = res['data']['message'] ?? 'Login failed';
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
    if (res['success']) {
      await ApiService.setToken(res['data']['token']);
      _user = User.fromJson(res['data']['user']);
      notifyListeners();
      return true;
    } else {
      _error = res['data']['message'] ?? 'Registration failed';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadUser() async {
    final token = await ApiService.getToken();
    if (token == null) return;

    final res = await ApiService.get('/auth/me');
    if (res['success']) {
      _user = User.fromJson(res['data']['user'] ?? res['data']);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await ApiService.post('/auth/logout', {});
    await ApiService.clearToken();
    _user = null;
    notifyListeners();
  }
}
