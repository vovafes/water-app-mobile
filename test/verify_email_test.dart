import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_app_mobile/main.dart';
import 'package:water_app_mobile/models/user.dart';
import 'package:water_app_mobile/providers/auth_provider.dart';
import 'package:water_app_mobile/providers/dashboard_provider.dart';
import 'package:water_app_mobile/providers/reminder_provider.dart';
import 'package:water_app_mobile/providers/theme_provider.dart';
import 'package:water_app_mobile/screens/auth/login_screen.dart';
import 'package:water_app_mobile/screens/auth/verify_email_screen.dart';

/// A new account is usable only once its email address is confirmed. The
/// backend answers 403 to everything else, so the app must show a screen that
/// can work (and not the dashboard, which would just fail) until then.
void main() {
  Map<String, dynamic> userJson({String? verifiedAt}) => {
    'id': 1,
    'name': 'Ana',
    'email': 'ana@example.com',
    'locale': 'en',
    'timezone': 'UTC',
    'onboarded_at': null,
    'email_verified_at': verifiedAt,
  };

  group('User', () {
    test('an address with no confirmation date is unconfirmed', () {
      expect(User.fromJson(userJson()).isEmailVerified, isFalse);
    });

    test('a confirmation date makes it confirmed', () {
      final u = User.fromJson(
        userJson(verifiedAt: '2026-11-18T10:00:00.000000Z'),
      );
      expect(u.isEmailVerified, isTrue);
    });
  });

  Future<List<http.Request>> boot(
    WidgetTester tester, {
    required String? verifiedAt,
    int resendStatus = 200,
  }) async {
    final requests = <http.Request>[];
    final client = MockClient((req) async {
      requests.add(req);
      if (req.url.path.endsWith('/auth/me')) {
        return http.Response(
          jsonEncode({'user': userJson(verifiedAt: verifiedAt)}),
          200,
        );
      }
      if (req.url.path.endsWith('/auth/email/verification-notification')) {
        return http.Response(jsonEncode({'sent': true}), resendStatus);
      }
      return http.Response('{}', 404);
    });

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
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }, () => client);
    });
    await tester.pump(const Duration(milliseconds: 100));
    return requests;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    SharedPreferences.setMockInitialValues({'auth_token': 'saved'});
  });

  testWidgets(
    'an unconfirmed account sees the confirmation screen, not the app',
    (tester) async {
      await boot(tester, verifiedAt: null);

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.text('Check your email'), findsOneWidget);
      expect(find.textContaining('ana@example.com'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    },
  );

  testWidgets('a confirmed account does not see it', (tester) async {
    await boot(tester, verifiedAt: '2026-11-18T10:00:00.000000Z');

    expect(find.byType(VerifyEmailScreen), findsNothing);
  });

  testWidgets(
    '"resend" is not available right after sign-up, and counts down',
    (tester) async {
      await boot(tester, verifiedAt: null);

      // The mail was sent when the account was made.
      expect(find.textContaining('Resend in'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
    },
  );

  testWidgets('once the wait is over, resend sends the mail and says so', (
    tester,
  ) async {
    final requests = await boot(tester, verifiedAt: null);

    await tester.pump(const Duration(seconds: 46));
    expect(find.text('Resend email'), findsOneWidget);

    await tester.runAsync(() async {
      await http.runWithClient(
        () async {
          await tester.tap(find.text('Resend email'));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        },
        () => MockClient((req) async {
          requests.add(req);
          return http.Response(jsonEncode({'sent': true}), 200);
        }),
      );
    });
    await tester.pump();

    expect(
      requests.where((r) => r.url.path.endsWith('/verification-notification')),
      hasLength(1),
    );
    expect(find.text('Email sent'), findsOneWidget);
    // And the wait starts again, so the six-an-hour limit is not burned through.
    expect(find.textContaining('Resend in'), findsOneWidget);
  });

  testWidgets(
    '"I\'ve confirmed it" while still unconfirmed says it is not confirmed yet',
    (tester) async {
      await boot(tester, verifiedAt: null);

      await tester.runAsync(() async {
        await http.runWithClient(
          () async {
            await tester.tap(find.text("I've confirmed it"));
            await Future<void>.delayed(const Duration(milliseconds: 200));
          },
          () => MockClient(
            (req) async => http.Response(jsonEncode({'user': userJson()}), 200),
          ),
        );
      });
      await tester.pump();

      expect(find.textContaining('Not confirmed yet'), findsOneWidget);
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    },
  );

  testWidgets('the screen has a way out for a mistyped address', (
    tester,
  ) async {
    await boot(tester, verifiedAt: null);

    expect(find.text('Wrong address? Log out'), findsOneWidget);
  });
}
