import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_app_mobile/providers/dashboard_provider.dart';

/// Logging a drink is the only thing this app exists to do, and it used to
/// wait on three sequential round-trips before the user saw anything move.
/// These tests hold the line on the fix: the totals go up in the same turn
/// of the event loop as the tap, they match what the server would have
/// computed, and a failed request puts everything back.
///
/// `ApiService` is all static methods over `package:http`'s top-level
/// functions, which resolve their `Client` from the current zone — so
/// `runWithClient` substitutes the transport without the provider needing
/// an injection seam it does not otherwise want.
void main() {
  /// Mirrors `DailyStatsService::recalculate`, which is what the real
  /// `/dashboard/today` returns.
  String dashboardJson({
    required int consumed,
    required int hydration,
    required int target,
    required int logs,
  }) => jsonEncode({
    'consumed_ml': consumed,
    'hydration_ml': hydration,
    'target_ml': target,
    'hydration_percent': target > 0
        ? ((hydration / target) * 100).clamp(0, 100).round()
        : 0,
    'completed_goal': hydration >= target,
    'logs_count': logs,
    'streak': 3,
    'recent_logs': const [],
    'popular_drinks': const [],
  });

  const catalogJson = '''
  {"drinks": [
    {"id": 1, "name": "Water", "slug": "water", "color": "#38bdf8",
     "hydration_multiplier": "1.00", "default_volumes": [200, 250, 500]},
    {"id": 7, "name": "Coffee", "slug": "coffee", "color": "#78350f",
     "hydration_multiplier": "0.60", "default_volumes": [100, 200]}
  ]}''';

  /// Serves a dashboard sitting at 500/2000 ml with the two-drink catalog,
  /// and hands every `POST /drink-logs` to [onLog].
  MockClient client({
    required Future<http.Response> Function(http.Request) onLog,
    int consumed = 500,
    int hydration = 500,
  }) => MockClient((req) async {
    final path = req.url.path;
    if (path.endsWith('/drink-logs') && req.method == 'POST') {
      return onLog(req);
    }
    if (path.endsWith('/dashboard/today')) {
      return http.Response(
        dashboardJson(
          consumed: consumed,
          hydration: hydration,
          target: 2000,
          logs: 2,
        ),
        200,
      );
    }
    if (path.endsWith('/drinks')) return http.Response(catalogJson, 200);
    return http.Response('{"message":"unexpected ${req.url}"}', 404);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the totals move before the request is answered', () async {
    // Never completes for the duration of the test: if the provider only
    // updated after the POST resolved, every expectation below would fail.
    final hung = Completer<http.Response>();
    addTearDown(() {
      if (!hung.isCompleted) hung.complete(http.Response('{}', 200));
    });

    await http.runWithClient(() async {
      final dash = DashboardProvider();
      await dash.loadDashboard();
      expect(dash.consumedMl, 500, reason: 'seeded from the fake dashboard');

      var notified = 0;
      dash.addListener(() => notified++);

      // Deliberately not awaited — that is the whole point.
      unawaited(dash.logDrink(1, 250));

      expect(dash.consumedMl, 750);
      expect(dash.logsCount, 3);
      expect(
        notified,
        1,
        reason: 'the UI is told once, immediately, not after the network',
      );
      expect(
        dash.recentLogs.first.volumeMl,
        250,
        reason: 'the new drink shows up in the list straight away',
      );
      expect(
        dash.recentLogs.first.id,
        isNegative,
        reason:
            'a provisional row must not carry an id anything could try to '
            'DELETE on the server',
      );
    }, () => client(onLog: (_) => hung.future));
  });

  test('the optimistic numbers are the ones the server would compute',
      () async {
    await http.runWithClient(() async {
      final dash = DashboardProvider();
      await dash.loadDashboard();

      // Coffee hydrates at 0.60, so 200 ml of it is 200 consumed but only
      // 120 toward the goal. Getting this wrong would show the ring jumping
      // once on the optimistic value and again on the server's correction.
      unawaited(dash.logDrink(7, 200));

      expect(dash.consumedMl, 700);
      expect(dash.hydrationMl, 620);
      expect(dash.hydrationPercent, 31, reason: '620/2000 rounded');
      expect(dash.completedGoal, isFalse);
    }, () => client(onLog: (_) async => http.Response('{"id": 99}', 201)));
  });

  test('crossing the goal flips completedGoal without waiting', () async {
    await http.runWithClient(() async {
      final dash = DashboardProvider();
      await dash.loadDashboard();
      expect(dash.completedGoal, isFalse);

      unawaited(dash.logDrink(1, 200));
      expect(
        dash.completedGoal,
        isTrue,
        reason:
            'the celebration has to land with the animation, not a '
            'round-trip later',
      );
    }, () => client(
          consumed: 1900,
          hydration: 1900,
          onLog: (_) async => http.Response('{"id": 99}', 201),
        ));
  });

  test('a rejected write is rolled back whole', () async {
    await http.runWithClient(() async {
      final dash = DashboardProvider();
      await dash.loadDashboard();

      final ok = await dash.logDrink(1, 250);

      expect(ok, isFalse);
      expect(dash.consumedMl, 500);
      expect(dash.hydrationMl, 500);
      expect(dash.logsCount, 2);
      expect(
        dash.recentLogs,
        isEmpty,
        reason: 'the provisional row goes with it',
      );
    }, () => client(
          onLog: (_) async =>
              http.Response('{"message": "validation failed"}', 422),
        ));
  });

  test('an offline write is rolled back too', () async {
    // ApiService turns a transport failure into `{success: false, status: 0}`
    // rather than throwing, so this exercises the same rollback by a
    // different route — the one a user on a train actually hits.
    await http.runWithClient(() async {
      final dash = DashboardProvider();
      await dash.loadDashboard();

      expect(await dash.logDrink(1, 250), isFalse);
      expect(dash.consumedMl, 500);
      expect(dash.logsCount, 2);
    }, () => client(
          onLog: (_) async => throw http.ClientException('connection refused'),
        ));
  });

  test('a confirmed write leaves the server totals in place', () async {
    // Outside the factory on purpose: `runWithClient` calls it once per
    // request, so state declared inside would reset between them.
    var logged = false;

    await http.runWithClient(() async {
      final dash = DashboardProvider();
      await dash.loadDashboard();

      expect(await dash.logDrink(1, 250), isTrue);
      // The fake dashboard starts answering 750 once the log has been
      // accepted, so the optimistic value and the authoritative one agree
      // and the user never sees a correction.
      expect(dash.consumedMl, 750);
    }, () {
      return MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/drink-logs')) {
          logged = true;
          return http.Response('{"id": 99}', 201);
        }
        if (path.endsWith('/dashboard/today')) {
          return http.Response(
            dashboardJson(
              consumed: logged ? 750 : 500,
              hydration: logged ? 750 : 500,
              target: 2000,
              logs: logged ? 3 : 2,
            ),
            200,
          );
        }
        if (path.endsWith('/drinks')) return http.Response(catalogJson, 200);
        return http.Response('{}', 404);
      });
    });
  });

  test('a refresh after logging does not re-fetch the drink catalog',
      () async {
    // Three round-trips per glass of water was the original problem. The
    // catalog cannot change because someone drank something, so the silent
    // refresh must skip it.
    var catalogCalls = 0;
    await http.runWithClient(() async {
      final dash = DashboardProvider();
      await dash.loadDashboard();
      expect(catalogCalls, 1);

      await dash.logDrink(1, 250);
      expect(catalogCalls, 1, reason: 'the silent refresh skipped /drinks');

      // An explicit pull-to-refresh still picks up a changed catalog.
      await dash.loadDashboard();
      expect(catalogCalls, 2);
    }, () => MockClient((req) async {
          final path = req.url.path;
          if (path.endsWith('/drinks')) {
            catalogCalls++;
            return http.Response(catalogJson, 200);
          }
          if (path.endsWith('/drink-logs')) {
            return http.Response('{"id": 99}', 201);
          }
          return http.Response(
            dashboardJson(
              consumed: 500,
              hydration: 500,
              target: 2000,
              logs: 2,
            ),
            200,
          );
        }));
  });

  test('a dashboard refresh does not shrink the picker to popular drinks',
      () async {
    // `/dashboard/today` carries only the six most-used. Once the full
    // catalog has landed, letting a later dashboard payload overwrite it
    // would make the picker lose drinks as the user used the app.
    await http.runWithClient(() async {
      final dash = DashboardProvider();
      await dash.loadDashboard();
      expect(dash.drinks, hasLength(2));

      await dash.loadDashboard();
      expect(dash.drinks, hasLength(2));
    }, () => MockClient((req) async {
          final path = req.url.path;
          if (path.endsWith('/drinks')) {
            return http.Response(catalogJson, 200);
          }
          return http.Response(
            jsonEncode({
              'consumed_ml': 500,
              'hydration_ml': 500,
              'target_ml': 2000,
              'hydration_percent': 25,
              'completed_goal': false,
              'logs_count': 2,
              'streak': 3,
              'recent_logs': const [],
              'popular_drinks': [
                {
                  'id': 1,
                  'name': 'Water',
                  'hydration_multiplier': '1.00',
                  'default_volumes': [250],
                },
              ],
            }),
            200,
          );
        }));
  });

  test('a silent refresh never raises the loading flag', () async {
    // The dashboard shows a full-screen spinner when `loading` is true and
    // there are no logs yet — which is exactly the state the first drink of
    // the day is logged from.
    await http.runWithClient(() async {
      final dash = DashboardProvider();
      await dash.loadDashboard();

      final seen = <bool>[];
      dash.addListener(() => seen.add(dash.loading));
      await dash.logDrink(1, 250);

      expect(
        seen,
        everyElement(isFalse),
        reason: 'the screen the user is looking at must not blank out',
      );
    }, () => client(onLog: (_) async => http.Response('{"id": 99}', 201)));
  });
}
