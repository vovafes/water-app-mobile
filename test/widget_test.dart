import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_app_mobile/main.dart';
import 'package:water_app_mobile/providers/auth_provider.dart';
import 'package:water_app_mobile/providers/dashboard_provider.dart';
import 'package:water_app_mobile/providers/reminder_provider.dart';
import 'package:water_app_mobile/providers/theme_provider.dart';
import 'package:water_app_mobile/screens/auth/login_screen.dart';

void main() {
  setUp(() async {
    // No stored token, so the post-frame loadUser() short-circuits before
    // it can reach the network.
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('boots to the login screen when logged out', (tester) async {
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
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
