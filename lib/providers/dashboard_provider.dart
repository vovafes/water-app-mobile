import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/drink_log.dart';
import '../models/drink.dart';

class DashboardProvider extends ChangeNotifier {
  double _todayIntake = 0;
  double _dailyGoal = 2000;
  double _hydrationScore = 0;
  List<DrinkLog> _todayLogs = [];
  List<Drink> _drinks = [];
  bool _loading = false;
  String? _error;

  double get todayIntake => _todayIntake;
  double get dailyGoal => _dailyGoal;
  double get hydrationScore => _hydrationScore;
  double get progress => _dailyGoal > 0 ? (_todayIntake / _dailyGoal).clamp(0.0, 1.0) : 0;
  List<DrinkLog> get todayLogs => _todayLogs;
  List<Drink> get drinks => _drinks;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadDashboard() async {
    _loading = true;
    _error = null;
    notifyListeners();

    final res = await ApiService.get('/dashboard/today');
    if (res['success']) {
      final data = res['data']['data'] ?? res['data'];
      _todayIntake = (data['total_intake'] ?? 0 as num).toDouble();
      _dailyGoal = (data['daily_goal'] ?? 2000 as num).toDouble();
      _hydrationScore = (data['hydration_score'] ?? 0 as num).toDouble();
      _todayLogs = (data['logs'] as List? ?? [])
          .map((e) => DrinkLog.fromJson(e))
          .toList();
    } else {
      _error = 'Failed to load dashboard';
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> loadDrinks() async {
    final res = await ApiService.get('/drinks/popular');
    if (res['success']) {
      final list = res['data']['data'] ?? res['data'];
      _drinks = (list as List).map((e) => Drink.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<bool> logDrink(int drinkId, double amount) async {
    final res = await ApiService.post('/drink-logs', {
      'drink_id': drinkId,
      'amount': amount,
    });
    if (res['success']) {
      await loadDashboard();
      return true;
    }
    return false;
  }

  Future<bool> deleteDrinkLog(int logId) async {
    final res = await ApiService.delete('/drink-logs/$logId');
    if (res['success']) {
      await loadDashboard();
      return true;
    }
    return false;
  }
}
