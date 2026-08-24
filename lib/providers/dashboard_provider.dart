import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
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
  bool _loaded = false;
  String? _error;

  /// True once `/drinks` has answered at least once.
  ///
  /// The dashboard response carries only `popular_drinks` — the user's six
  /// most-used. The full catalog comes from a second request, and once it
  /// has landed a later dashboard payload must not shrink the picker back
  /// down to six. See [_applyDashboard].
  bool _fullCatalog = false;

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

  /// True once a dashboard response has actually landed.
  ///
  /// [targetMl] starts at a placeholder 2000 so the progress ring has
  /// something to divide by on the first frame. That number is not the
  /// user's goal, and anything that *presents* it as personal — the
  /// paywall's opening line, for one — has to wait for this.
  bool get hasLoaded => _loaded;

  /// Progress fraction toward target, clamped to [0, 1].
  double get progress {
    if (_targetMl <= 0) return 0;
    return (_consumedMl / _targetMl).clamp(0.0, 1.0);
  }

  // ---- Actions ----------------------------------------------------------

  /// Fetches today's dashboard.
  ///
  /// [silent] keeps [loading] down for the duration. A refresh that follows
  /// an action the user already saw succeed must not blank the screen they
  /// are looking at — on the first drink of the day `recentLogs` is still
  /// empty, so the non-silent path would drop the whole dashboard to a
  /// centred spinner at exactly the wrong moment.
  Future<void> loadDashboard({bool silent = false}) async {
    _error = null;
    if (!silent) {
      _loading = true;
      notifyListeners();
    }

    final res = await ApiService.get('/dashboard/today');
    if (res['success'] == true && res['data'] is Map<String, dynamic>) {
      _loaded = true;
      _applyDashboard(res['data'] as Map<String, dynamic>);
    } else {
      _error = 'Failed to load dashboard'.tr();
    }

    // The full active drink catalog, so the picker has more than the six
    // most-used. `/drinks` returns `{drinks: [...]}` per
    // DrinkController::index.
    //
    // Only worth re-fetching when the user asked for a refresh: the catalog
    // does not change because they logged a glass of water, and skipping it
    // halves the round-trips on the app's hottest path.
    if (!silent || !_fullCatalog) {
      final dr = await ApiService.get('/drinks');
      if (dr['success'] == true && dr['data'] is Map<String, dynamic>) {
        final body = dr['data'] as Map<String, dynamic>;
        final list = body['drinks'];
        if (list is List) {
          _drinks = list
              .whereType<Map<String, dynamic>>()
              .map(Drink.fromJson)
              .toList();
          _fullCatalog = true;
        }
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

    // Only while the full catalog is still missing — otherwise every
    // dashboard refresh would shrink the picker back to six drinks.
    final pop = d['popular_drinks'];
    if (pop is List && !_fullCatalog) {
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

  Drink? _drinkById(int id) {
    for (final d in _drinks) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// What the backend calls this client. `DrinkLogController` validates
  /// against `in:web,ios,android,watch,api`, and the value is stored, so a
  /// hardcoded 'android' would mislabel every log made on an iPhone.
  static String get _source {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'api';
  }

  /// Logs a drink consumption. Returns true once the server has confirmed it.
  ///
  /// The totals move *before* the request goes out. Logging a drink is the
  /// one thing this app exists to do, and making it wait on a round-trip
  /// makes the whole app feel dead on a slow connection. The optimistic
  /// numbers mirror `DailyStatsService::recalculate` exactly, so the
  /// authoritative refresh that follows is a no-op rather than a correction
  /// the user can see. A failure rolls the whole snapshot back.
  ///
  /// The rollback assumes writes are serial, which they are today: the only
  /// caller closes its sheet in the same frame it calls this. A quick-add
  /// button that let two logs be in flight at once would need per-log
  /// deltas here instead of a whole-state snapshot.
  Future<bool> logDrink(int drinkId, double volumeMl) async {
    final drink = _drinkById(drinkId);

    final before = _Snapshot.of(this);

    _consumedMl += volumeMl;
    _hydrationMl += volumeMl * (drink?.hydrationMultiplier ?? 1.0);
    _hydrationPercent = _targetMl > 0
        ? (_hydrationMl / _targetMl * 100).clamp(0, 100).roundToDouble()
        : 0;
    _completedGoal = _hydrationMl >= _targetMl;
    _logsCount += 1;
    _recentLogs = [
      DrinkLog(
        // Negative so nothing can mistake it for a server row and try to
        // DELETE it. The dashboard list is read-only; the refresh below
        // replaces this entry with the real one within the second.
        id: -1,
        drinkId: drinkId,
        drinkName: drink?.name ?? 'Drink',
        drinkColor: drink?.color,
        drinkIconPath: drink?.iconPath,
        volumeMl: volumeMl,
        hydrationMl: volumeMl * (drink?.hydrationMultiplier ?? 1.0),
        consumedAt: DateTime.now(),
      ),
      ..._recentLogs,
    ];
    notifyListeners();

    final res = await ApiService.post('/drink-logs', {
      'drink_id': drinkId,
      'volume_ml': volumeMl.round(),
      'source': _source,
    });

    if (res['success'] != true) {
      before.restoreTo(this);
      notifyListeners();
      return false;
    }

    await loadDashboard(silent: true);
    return true;
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

/// The slice of dashboard state an optimistic write touches, kept so a
/// failed request can put it back exactly as it was.
class _Snapshot {
  final double consumedMl;
  final double hydrationMl;
  final double hydrationPercent;
  final bool completedGoal;
  final int logsCount;
  final List<DrinkLog> recentLogs;

  const _Snapshot({
    required this.consumedMl,
    required this.hydrationMl,
    required this.hydrationPercent,
    required this.completedGoal,
    required this.logsCount,
    required this.recentLogs,
  });

  factory _Snapshot.of(DashboardProvider p) => _Snapshot(
    consumedMl: p._consumedMl,
    hydrationMl: p._hydrationMl,
    hydrationPercent: p._hydrationPercent,
    completedGoal: p._completedGoal,
    logsCount: p._logsCount,
    recentLogs: p._recentLogs,
  );

  void restoreTo(DashboardProvider p) {
    p._consumedMl = consumedMl;
    p._hydrationMl = hydrationMl;
    p._hydrationPercent = hydrationPercent;
    p._completedGoal = completedGoal;
    p._logsCount = logsCount;
    p._recentLogs = recentLogs;
  }
}
