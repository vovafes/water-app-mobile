import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class ReminderProvider extends ChangeNotifier {
  List<Reminder> _reminders = const [];
  bool _loading = false;
  bool _permissionGranted = true;
  String? _error;

  List<Reminder> get reminders => _reminders;
  bool get loading => _loading;
  bool get permissionGranted => _permissionGranted;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    final res = await ApiService.get('/reminders');
    if (res['success'] == true && res['data'] is Map<String, dynamic>) {
      final list = (res['data'] as Map<String, dynamic>)['reminders'];
      if (list is List) {
        _reminders = list
            .whereType<Map<String, dynamic>>()
            .map(Reminder.fromJson)
            .toList();
      }
    } else {
      _error = 'Could not load reminders'.tr();
    }

    _loading = false;
    notifyListeners();
    await _resync();
  }

  Future<bool> create(Reminder draft) async {
    final res = await ApiService.post('/reminders', draft.toJson());
    if (res['success'] != true) {
      _error = _messageFrom(res);
      notifyListeners();
      return false;
    }
    final body = res['data'];
    if (body is Map<String, dynamic> && body['reminder'] is Map) {
      _reminders = [
        ..._reminders,
        Reminder.fromJson(Map<String, dynamic>.from(body['reminder'] as Map)),
      ];
    }
    _error = null;
    notifyListeners();
    await _resync();
    return true;
  }

  Future<bool> update(Reminder reminder) async {
    final res = await ApiService.put(
      '/reminders/${reminder.id}',
      reminder.toJson(),
    );
    if (res['success'] != true) {
      _error = _messageFrom(res);
      notifyListeners();
      return false;
    }
    final body = res['data'];
    final updated = body is Map<String, dynamic> && body['reminder'] is Map
        ? Reminder.fromJson(Map<String, dynamic>.from(body['reminder'] as Map))
        : reminder;
    _reminders = [for (final r in _reminders) r.id == updated.id ? updated : r];
    _error = null;
    notifyListeners();
    await _resync();
    return true;
  }

  Future<bool> remove(int id) async {
    final res = await ApiService.delete('/reminders/$id');
    if (res['success'] != true) {
      _error = _messageFrom(res);
      notifyListeners();
      return false;
    }
    _reminders = _reminders.where((r) => r.id != id).toList();
    _error = null;
    notifyListeners();
    await _resync();
    return true;
  }

  /// Prompts for the OS notification permission and re-schedules on success.
  Future<bool> requestPermission() async {
    _permissionGranted = await NotificationService.requestPermission();
    notifyListeners();
    if (_permissionGranted) await _resync();
    return _permissionGranted;
  }

  Future<void> _resync() async {
    await NotificationService.init();
    _permissionGranted = await NotificationService.hasPermission();
    await NotificationService.syncAll(_reminders);
    notifyListeners();
  }

  /// Drops local state on logout so the next account does not inherit
  /// the previous user's notifications.
  Future<void> clear() async {
    _reminders = const [];
    _error = null;
    await NotificationService.cancelAll();
    notifyListeners();
  }

  String _messageFrom(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Could not save'.tr();
  }
}
