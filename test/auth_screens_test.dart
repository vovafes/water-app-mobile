import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_app_mobile/main.dart';
import 'package:water_app_mobile/providers/auth_provider.dart';
import 'package:water_app_mobile/screens/auth/forgot_password_screen.dart';
import 'package:water_app_mobile/screens/auth/login_screen.dart';
import 'package:water_app_mobile/screens/auth/register_screen.dart';

/// The sign-in screen offers a way back in for someone who forgot their
/// password, and the sign-up screen refuses to create an account until both
/// consent boxes are ticked (the server refuses too; this is the app saying so
/// before a round trip).
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  /// Pumps [home] inside the localisation and provider wrappers, with every
  /// request answered by [handler].
  Future<List<http.Request>> boot(
    WidgetTester tester,
    Widget home,
    Future<http.Response> Function(http.Request) handler,
  ) async {
    final requests = <http.Request>[];
    final client = MockClient((req) async {
      requests.add(req);
      return handler(req);
    });

    await tester.runAsync(() async {
      await http.runWithClient(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: supportedLocales,
            path: 'assets/i18n',
            fallbackLocale: const Locale('en'),
            useFallbackTranslations: true,
            child: ChangeNotifierProvider(
              create: (_) => AuthProvider(),
              child: Builder(
                builder: (context) => MaterialApp(
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: const Locale('en'),
                  home: home,
                ),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }, () => client);
    });
    await tester.pump(const Duration(milliseconds: 100));
    return requests;
  }

  /// Runs [action] (taps, typing) with [handler] answering the network.
  Future<void> act(
    WidgetTester tester,
    List<http.Request> requests,
    Future<http.Response> Function(http.Request) handler,
    Future<void> Function() action,
  ) async {
    await tester.runAsync(() async {
      await http.runWithClient(
        () async {
          await action();
          await Future<void>.delayed(const Duration(milliseconds: 200));
        },
        () => MockClient((req) async {
          requests.add(req);
          return handler(req);
        }),
      );
    });
    await tester.pump();
  }

  Future<http.Response> ok(http.Request _) async =>
      http.Response(jsonEncode({'sent': true}), 200);

  group('forgot password', () {
    testWidgets('the sign-in screen has the link, and it carries the typed '
        'address over', (tester) async {
      await boot(tester, const LoginScreen(), ok);

      expect(find.text('Forgot password?'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'ana@example.com');
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(find.text('ana@example.com'), findsOneWidget);
    });

    testWidgets('nothing can be sent without an address', (tester) async {
      await boot(tester, const ForgotPasswordScreen(), ok);

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.enterText(find.byType(TextField), 'ana@example.com');
      await tester.pump();

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('sending asks the server and confirms without naming the '
        'address', (tester) async {
      final requests = await boot(
        tester,
        const ForgotPasswordScreen(initialEmail: 'ana@example.com'),
        ok,
      );

      await act(
        tester,
        requests,
        ok,
        () => tester.tap(find.byType(FilledButton)),
      );

      final sent = requests.where(
        (r) => r.url.path.endsWith('/auth/forgot-password'),
      );
      expect(sent, hasLength(1));
      expect(jsonDecode(sent.single.body), {'email': 'ana@example.com'});

      expect(find.text('Check your email'), findsOneWidget);
      // Worded as "if", so it does not say whether the address has an account.
      expect(
        find.textContaining('If that address has an account'),
        findsOneWidget,
      );
      expect(find.textContaining('ana@example.com'), findsNothing);
      expect(find.text('Back to sign in'), findsOneWidget);
    });

    testWidgets('too many requests says to wait, and stays on the form', (
      tester,
    ) async {
      final requests = await boot(
        tester,
        const ForgotPasswordScreen(initialEmail: 'ana@example.com'),
        ok,
      );

      await act(
        tester,
        requests,
        (_) async => http.Response(jsonEncode({'sent': false}), 429),
        () => tester.tap(find.byType(FilledButton)),
      );

      expect(find.textContaining('Too many attempts'), findsOneWidget);
      expect(find.text('Send reset link'), findsOneWidget);
    });

    testWidgets("the server's own complaint about the address is shown", (
      tester,
    ) async {
      final requests = await boot(
        tester,
        const ForgotPasswordScreen(initialEmail: 'nope'),
        ok,
      );

      await act(
        tester,
        requests,
        (_) async => http.Response(
          jsonEncode({
            'message': 'The email field must be a valid email address.',
            'errors': {
              'email': ['The email field must be a valid email address.'],
            },
          }),
          422,
        ),
        () => tester.tap(find.byType(FilledButton)),
      );

      expect(
        find.text('The email field must be a valid email address.'),
        findsOneWidget,
      );
    });

    testWidgets('a server error says it could not send, not that it worked', (
      tester,
    ) async {
      final requests = await boot(
        tester,
        const ForgotPasswordScreen(initialEmail: 'ana@example.com'),
        ok,
      );

      await act(
        tester,
        requests,
        (_) async => http.Response('boom', 500),
        () => tester.tap(find.byType(FilledButton)),
      );

      expect(find.textContaining('Could not send the link'), findsOneWidget);
      expect(find.text('Check your email'), findsNothing);
    });
  });

  group('sign-up consent', () {
    FilledButton button(WidgetTester t) =>
        t.widget<FilledButton>(find.byType(FilledButton));

    Future<void> fill(WidgetTester t) async {
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'Ana');
      await t.enterText(fields.at(1), 'ana@example.com');
      await t.enterText(fields.at(2), 'Str0ngPassw0rd!');
    }

    testWidgets('neither box is ticked at first, and the button waits', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await boot(tester, const RegisterScreen(), ok);
      await fill(tester);
      await tester.pump();

      final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(boxes, hasLength(2));
      expect(boxes.map((b) => b.value), [false, false]);
      expect(button(tester).onPressed, isNull);
    });

    testWidgets('one box is not enough', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await boot(tester, const RegisterScreen(), ok);
      await fill(tester);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pump();
      expect(button(tester).onPressed, isNull, reason: 'terms only');

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      expect(button(tester).onPressed, isNull, reason: 'health only');
    });

    testWidgets('both ticked: the account is requested with both flags', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final requests = await boot(tester, const RegisterScreen(), ok);
      await fill(tester);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      expect(button(tester).onPressed, isNotNull);

      await act(
        tester,
        requests,
        (_) async => http.Response('{}', 500),
        () => tester.tap(find.byType(FilledButton)),
      );

      final signUp = requests.where(
        (r) => r.url.path.endsWith('/auth/register'),
      );
      expect(signUp, hasLength(1));
      final body = jsonDecode(signUp.single.body) as Map<String, dynamic>;
      expect(body['terms'], isTrue);
      expect(body['health_consent'], isTrue);
      expect(body['email'], 'ana@example.com');
    });

    testWidgets('the Terms and the Privacy Policy stay one tap away', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await boot(tester, const RegisterScreen(), ok);

      expect(find.text('Terms of Use'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });
  });
}
