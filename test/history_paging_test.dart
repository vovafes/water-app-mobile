import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_app_mobile/providers/dashboard_provider.dart';
import 'package:water_app_mobile/screens/diary/history_screen.dart';

/// The history used to fetch the 200 newest entries and stop, so the oldest
/// ones silently disappeared from "All" after a few weeks of logging. It now
/// loads a page at a time, with a "Load more" at the end.
void main() {
  Map<String, dynamic> log(int id, String at, num ml) => {
    'id': id,
    'drink_id': 1,
    'volume_ml': ml,
    'hydration_ml': ml,
    'consumed_at': at,
    'drink': {'name': 'Still water', 'slug': 'still-water', 'color': '#3B82F6'},
  };

  Future<List<Uri>> show(
    WidgetTester tester, {
    required Map<int, Map<String, dynamic>> pages,
  }) async {
    final requested = <Uri>[];
    final client = MockClient((req) async {
      requested.add(req.url);
      final page = int.parse(req.url.queryParameters['page'] ?? '1');
      return http.Response(
        jsonEncode(pages[page] ?? {'data': [], 'last_page': 1}),
        200,
      );
    });

    await tester.runAsync(() async {
      await http.runWithClient(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en')],
            path: 'assets/i18n',
            fallbackLocale: const Locale('en'),
            child: Builder(
              builder: (context) => ChangeNotifierProvider(
                create: (_) => DashboardProvider(),
                child: MaterialApp(
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                  home: const HistoryScreen(),
                ),
              ),
            ),
          ),
        );
        // Translations load asynchronously and the screen is only built on a
        // later frame; that frame has to run in this zone too, or the screen
        // would talk to the real network instead of the mock.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();
      }, () => client);
    });
    await tester.pump(const Duration(milliseconds: 100));
    return requested;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  final firstPage = {
    'current_page': 1,
    'last_page': 2,
    'data': [
      log(3, '2026-11-17T12:00:00Z', 250),
      log(2, '2026-11-17T09:00:00Z', 300),
    ],
  };
  final secondPage = {
    'current_page': 2,
    'last_page': 2,
    'data': [log(1, '2026-11-17T07:00:00Z', 500)],
  };

  testWidgets('asks for a page of 50, not the 200 newest', (tester) async {
    final requested = await show(tester, pages: {1: firstPage, 2: secondPage});

    expect(requested.first.queryParameters['per_page'], '50');
    expect(requested.first.queryParameters['page'], '1');
  });

  testWidgets('offers "Load more" while pages remain, and not after the last', (
    tester,
  ) async {
    await show(
      tester,
      pages: {
        1: {...firstPage, 'last_page': 1},
      },
    );

    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('"Load more" fetches the next page and adds its entries', (
    tester,
  ) async {
    final requested = await show(tester, pages: {1: firstPage, 2: secondPage});
    expect(find.text('Load more'), findsOneWidget);
    expect(find.text('500 ml'), findsNothing);

    await tester.runAsync(() async {
      await http.runWithClient(
        () async {
          await tester.ensureVisible(find.text('Load more'));
          await tester.tap(find.text('Load more'));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        },
        () => MockClient((req) async {
          requested.add(req.url);
          return http.Response(jsonEncode(secondPage), 200);
        }),
      );
    });
    await tester.pump();

    expect(requested.last.queryParameters['page'], '2');
    expect(find.text('500 ml'), findsWidgets);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('a day that may continue on the next page shows no total', (
    tester,
  ) async {
    await show(tester, pages: {1: firstPage, 2: secondPage});

    // All three entries are the same day, so the only block is "the oldest day
    // loaded", whose total would be wrong until the rest arrives.
    expect(find.text('550 ml'), findsNothing);
    expect(find.text('250 ml'), findsOneWidget);
  });
}
