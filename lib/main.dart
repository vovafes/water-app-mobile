import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/achievements/achievements_screen.dart';
import 'screens/diary/history_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/tips/tips_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'theme.dart';

/// All four locales the web app supports. The English text doubles as
/// the translation key (mirroring the Laravel `__('...')` pattern), so
/// `assets/i18n/en.json` is essentially an identity map.
const supportedLocales = <Locale>[
  Locale('en'),
  Locale('de'),
  Locale('ru'),
  Locale('uk'),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  // Loads month/weekday names for every locale intl knows about; needed
  // before DateFormat with a non-default locale can format anything.
  await initializeDateFormatting();

  runApp(
    EasyLocalization(
      supportedLocales: supportedLocales,
      path: 'assets/i18n',
      fallbackLocale: const Locale('en'),
      useFallbackTranslations: true,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const WaterApp(),
      ),
    ),
  );
}

class WaterApp extends StatefulWidget {
  const WaterApp({super.key});

  @override
  State<WaterApp> createState() => _WaterAppState();
}

class _WaterAppState extends State<WaterApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().loadUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    // When auth loads (or refreshes) the user's preferred locale,
    // propagate it to EasyLocalization. Skips if the stored device
    // locale already matches so we don't churn frames on every build.
    final user = context.watch<AuthProvider>().user;
    final preferred = user?.locale;
    if (preferred != null) {
      final desired = Locale(preferred);
      final current = context.locale;
      if (current.languageCode != desired.languageCode &&
          supportedLocales.any((l) => l.languageCode == desired.languageCode)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.setLocale(desired);
        });
      }
    }

    return MaterialApp(
      title: 'Water App',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: theme.mode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  int _tab = 0;

  final GlobalKey<HistoryScreenState> _historyKey =
      GlobalKey<HistoryScreenState>();

  late final List<Widget> _screens = [
    const DashboardScreen(),
    HistoryScreen(key: _historyKey),
    const AchievementsScreen(),
    const TipsScreen(),
    const ProfileScreen(),
  ];

  void _onTabSelected(int index) {
    setState(() => _tab = index);
    if (index == 1) {
      _historyKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    if (auth.needsOnboarding) {
      return const OnboardingScreen();
    }

    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _onTabSelected,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.water_drop_outlined),
            selectedIcon: const Icon(Icons.water_drop),
            label: 'Dashboard'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: 'History'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.emoji_events_outlined),
            selectedIcon: const Icon(Icons.emoji_events),
            label: 'Achievements'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.lightbulb_outlined),
            selectedIcon: const Icon(Icons.lightbulb),
            label: 'Tips'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outlined),
            selectedIcon: const Icon(Icons.person),
            label: 'Profile'.tr(),
          ),
        ],
      ),
    );
  }
}
