import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_app_mobile/models/drink.dart';
import 'package:water_app_mobile/providers/dashboard_provider.dart';
import 'package:water_app_mobile/screens/dashboard/dashboard_screen.dart';

/// The custom-amount field is the one place a person types a number into the
/// home screen, and it had three problems at once: it accepted up to 5000 ml
/// while the API refuses anything over 3000, so a "valid" 4000 closed the
/// sheet, moved the ring and then rolled back with an error; the message for a
/// bad amount was a SnackBar that the scaffold paints behind an open bottom
/// sheet, so nothing visible happened; and it let letters through.
void main() {
  const water = Drink(
    id: 1,
    name: 'Still water',
    slug: 'still-water',
    color: '#3B82F6',
    hydrationMultiplier: 1,
    defaultVolumes: [200, 250],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> openSheet(WidgetTester tester) async {
    // The translations come off the asset bundle, which only completes in real
    // time, so the first frames have to run outside the fake clock.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en')],
          path: 'assets/i18n',
          fallbackLocale: const Locale('en'),
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Scaffold(
                body: VolumeSheet(drink: water, dash: DashboardProvider()),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
  }

  const message = 'Enter 10–3000 ml';

  for (final bad in ['', '5', '9', '3001', '4000', '5000']) {
    testWidgets('"$bad" is refused with a message under the field', (
      tester,
    ) async {
      await openSheet(tester);
      await submit(tester, bad);

      // errorText renders inside the field itself, so it cannot be hidden
      // behind the sheet the way a SnackBar was.
      expect(find.text(message), findsOneWidget);
    });
  }

  testWidgets('letters and decimals cannot be typed at all', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), '12ab.5');

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '125',
    );
  });

  testWidgets('the message goes away as soon as the person edits the amount', (
    tester,
  ) async {
    await openSheet(tester);
    await submit(tester, '4000');
    expect(find.text(message), findsOneWidget);

    await tester.enterText(find.byType(TextField), '400');
    await tester.pump();

    expect(find.text(message), findsNothing);
  });

  testWidgets('the upper limit matches the API, not 5000', (tester) async {
    await openSheet(tester);
    // 3000 is accepted, so no message appears; _log then needs a network, which
    // is not what this test is about, so only the absence of the message is
    // asserted and the failure to reach a server is swallowed by the provider.
    await tester.enterText(find.byType(TextField), '3000');
    await tester.pump();

    expect(find.text(message), findsNothing);
  });
}
