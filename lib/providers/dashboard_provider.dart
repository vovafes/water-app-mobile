import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/drink_log.dart';
import '../models/drink.dart';

class DashboardProvider extends ChangeNotifier {
  double _consumedMl = 0;
  double _hydrationMl = 0;
  double _targetMl = 2000;
  double _hydrationPercent = 0;
  bool _completedGoal = false;
  int _logsCount = 0;
  int _streak = 0;
  List<int> _quickVolumes = const [100, 200, 250, 330, 500];
  List<DrinkLog> _recentLogs = const [];
  List<Drink> _drinks = const [];
  bool _loading = false;
  String? _error;

  // ---- Getters ----------------------------------------------------------

  double get consumedMl => _consumedMl;
  double get hydrationMl => _hydrationMl;
  double get targetMl => _targetMl;
  double get hydrationPercent => _hydrationPercent;
  bool get completedGoal => _completedGoal;
  int get logsCount => _logsCount;
  int get streak => _streak;
  List<int> get quickVolumes => _quickVolumes;
  List<DrinkLog> get recentLogs => _recentLogs;
  List<Drink> get drinks => _drinks;
  bool get loading => _loading;
  String? get error => _error;

  /// Progress fraction toward target, clamped to [0, 1].
  double get progress {
    if (_targetMl <= 0) return 0;
    return (_consumedMl / _targetMl).clamp(0.0, 1.0);
  }

  // ---- Actions ----------------------------------------------------------

  Future<void> loadDashboard() async {
    _loading = true;
    _error = null;
    notifyListeners();

    final res = await ApiService.get('/dashboard/today');
    if (res['success'] == true && res['data'] is Map<String, dynamic>) {
      _applyDashboard(res['data'] as Map<String, dynamic>);
    } else {
      _error = 'Failed to load dashboard'.tr();
    }

    // Also load the full active drink catalog so the dashboard picker
    // has more than just the user's 6 most-used. /drinks returns
    // `{drinks: [...]}` per DrinkController::index.
    final dr = await ApiService.get('/drinks');
    if (dr['success'] == true && dr['data'] is Map<String, dynamic>) {
      final body = dr['data'] as Map<String, dynamic>;
      final list = body['drinks'];
      if (list is List) {
        _drinks = list
            .whereType<Map<String, dynamic>>()
            .map(Drink.fromJson)
            .toList();
      }
    }

    _loading = false;
    notifyListeners();
  }

  void _applyDashboard(Map<String, dynamic> d) {
    // Local helpers — must not be named `num` or they'd shadow the dart:core
    // type and break the `v is num` check.
    double readDouble(dynamic v, [double fallback = 0]) =>
        v is num ? v.toDouble() : fallback;
    int readInt(dynamic v, [int fallback = 0]) =>
        v is num ? v.toInt() : fallback;

    _consumedMl = readDouble(d['consumed_ml']);
    _hydrationMl = readDouble(d['hydration_ml']);
    _targetMl = readDouble(d['target_ml'], 2000);
    _hydrationPercent = readDouble(d['hydration_percent']);
    _completedGoal = d['completed_goal'] == true;
    _logsCount = readInt(d['logs_count']);
    _streak = readInt(d['streak']);

    final qv = d['quick_volumes'];
    if (qv is List && qv.isNotEmpty) {
      _quickVolumes = qv.whereType<num>().map((e) => e.toInt()).toList();
    }

    final logs = d['recent_logs'];
    if (logs is List) {
      _recentLogs = logs
          .whereType<Map<String, dynamic>>()
          .map(DrinkLog.fromJson)
          .toList();
    }

    final pop = d['popular_drinks'];
    if (pop is List) {
      _drinks = pop
          .whereType<Map<String, dynamic>>()
          .map(Drink.fromJson)
          .toList();
    }
  }

  /// Backwards-compat alias so old call sites that did `loadDrinks()` still
  /// work — popular drinks are now bundled in the dashboard response, so we
  /// just defer to it.
  Future<void> loadDrinks() async {
    if (_drinks.isNotEmpty) return;
    await loadDashboard();
  }

  /// Logs a drink consumption. Returns true on success.
  Future<bool> logDrink(int drinkId, double volumeMl) async {
    final res = await ApiService.post('/drink-logs', {
      'drink_id': drinkId,
      'volume_ml': volumeMl.round(),
      'source': 'android',
    });
    if (res['success'] == true) {
      await loadDashboard();
      return true;
    }
    return false;
  }

  Future<bool> deleteDrinkLog(int logId) async {
    final res = await ApiService.delete('/drink-logs/$logId');
    if (res['success'] == true) {
      await loadDashboard();
      return true;
    }
    return false;
  }
}
