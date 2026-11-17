import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_app_mobile/main.dart';
import 'package:water_app_mobile/providers/auth_provider.dart';
import 'package:water_app_mobile/providers/dashboard_provider.dart';
import 'package:water_app_mobile/providers/reminder_provider.dart';
import 'package:water_app_mobile/providers/theme_provider.dart';
import 'package:water_app_mobile/screens/auth/login_screen.dart';
import 'package:water_app_mobile/widgets/session_splash.dart';

/// Someone who is already signed in used to see the sign-in form on every cold
/// start for as long as /auth/me took, and on a bad connection stayed on it.
/// The saved session is now confirmed behind a splash, and an unreachable
/// server gets a retry screen instead of a login form.
void main() {
  Future<void> boot(WidgetTester tester, http.Client client) async {
    await tester.runAsync(() async {
      await http.runWithClient(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: supportedLocales,
            path: 'assets/i18n',
            fallbackLocale: const Locale('en'),
            useFallbackTranslations: true,
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => AuthProvider()),
                ChangeNotifierProvider(create: (_) => DashboardProvider()),
                ChangeNotifierProvider(create: (_) => ReminderProvider()),
                ChangeNotifierProvider(create: (_) => ThemeProvider()),
              ],
              child: const WaterApp(),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }, () => client);
    });
    await tester.pump(const Duration(milliseconds: 100));
  }

  setUp(() async {
    // easy_localization reads shared_preferences while initialising.
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets(
    'with a saved session, the first frames are not the sign-in form',
    (tester) async {
      SharedPreferences.setMockInitialValues({'auth_token': 'saved'});
      final pending = Completer<http.Response>();
      await boot(tester, MockClient((_) => pending.future));

      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(SessionSplash), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'a saved session and an unreachable server gets a retry, not a login form',
    (tester) async {
      SharedPreferences.setMockInitialValues({'auth_token': 'saved'});
      await boot(
        tester,
        MockClient((_) async => throw http.ClientException('offline')),
      );

      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('No connection to the server'), findsOneWidget);
    },
  );

  testWidgets('a saved session the server no longer accepts goes to sign-in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'auth_token': 'expired'});
    await boot(
      tester,
      MockClient(
        (_) async => http.Response('{"message":"Unauthenticated."}', 401),
      ),
    );

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString('auth_token'),
      isNull,
    );
  });

  testWidgets('with no saved session it goes straight to sign-in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await boot(tester, MockClient((_) async => http.Response('{}', 200)));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SessionSplash), findsNothing);
  });
}
