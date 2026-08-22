import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_app_mobile/main.dart';
import 'package:water_app_mobile/models/entitlement.dart';
import 'package:water_app_mobile/providers/auth_provider.dart';
import 'package:water_app_mobile/providers/dashboard_provider.dart';
import 'package:water_app_mobile/screens/paywall/paywall_screen.dart';
import 'package:water_app_mobile/services/purchase_service.dart';

/// Reports whatever the test asks it to, and records what it was told to
/// buy, so the screen can be driven without a store.
class _FakePurchases implements PurchaseService {
  final PurchaseResult result;
  final bool restorable;
  String? purchased;
  int restoreCalls = 0;

  _FakePurchases({
    this.result = PurchaseResult.success,
    this.restorable = false,
  });

  @override
  Future<List<PremiumPlan>> plans() async => const [
    PremiumPlan(
      productId: PremiumProducts.annual,
      tier: PremiumTier.annual,
      price: r'$29.99',
      perMonth: r'$2.50',
      savingBadge: '-50%',
      trial: Duration(days: 3),
    ),
    PremiumPlan(
      productId: PremiumProducts.monthly,
      tier: PremiumTier.monthly,
      price: r'$4.99',
    ),
    PremiumPlan(
      productId: PremiumProducts.lifetime,
      tier: PremiumTier.lifetime,
      price: r'$59.99',
    ),
  ];

  @override
  Future<PurchaseResult> purchase(String productId) async {
    purchased = productId;
    return result;
  }

  @override
  Future<bool> restore() async {
    restoreCalls++;
    return restorable;
  }
}

/// Everything lives in one `testWidgets` on purpose.
///
/// EasyLocalization does not survive the binding reset between test cases:
/// the first case in a file renders, every later one comes up with an empty
/// frame because the localization delegate's future never resolves again.
/// Re-pumping inside a single case works fine, so the screen is driven
/// through its states here rather than split into cases that pass
/// individually and fail as a suite.
///
/// The locale is pinned to English. Without `startLocale` the suite renders
/// in whatever the build machine's locale happens to be — this one is
/// ru-UA — and every `find.text` below fails for the wrong reason.
void main() {
  Widget wrap(PurchaseService purchases) => EasyLocalization(
    supportedLocales: supportedLocales,
    path: 'assets/i18n',
    fallbackLocale: const Locale('en'),
    startLocale: const Locale('en'),
    saveLocale: false,
    useFallbackTranslations: true,
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: PaywallScreen(
            source: 'test',
            targetMl: 2640,
            purchases: purchases,
          ),
        ),
      ),
    ),
  );

  testWidgets('the paywall', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();

    Future<void> show(PurchaseService purchases) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(wrap(purchases));
      await tester.pumpAndSettle();
    }

    // ---- App Review requirements ------------------------------------
    // These are why paywalls get rejected, not style choices. If one starts
    // failing, the build is not shippable.

    var purchases = _FakePurchases();
    await show(purchases);

    expect(
      find.byIcon(Icons.close),
      findsOneWidget,
      reason:
          'the close control must be on screen in the first frame '
          '(Guideline 3.1.2)',
    );

    expect(
      find.text(r'Then $29.99/yr · Cancel anytime'),
      findsOneWidget,
      reason: 'both stores require the post-trial price on the paywall',
    );

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(purchases.restoreCalls, 1, reason: 'Restore must always work');

    // ---- Declining is offered, and not as a guilt trip ---------------

    expect(find.text('Continue with the free plan'), findsOneWidget);

    // ---- The goal from onboarding opens the screen -------------------

    expect(find.textContaining('640'), findsOneWidget);
    expect(find.text('ml — your daily goal'), findsOneWidget);

    // ---- Opens on the annual plan -----------------------------------
    // Last in this pass: a successful purchase pops the screen, so nothing
    // can be asserted about it afterwards.

    expect(find.text('Try 3 days free'), findsOneWidget);
    await tester.tap(find.text('Try 3 days free'));
    await tester.pumpAndSettle();
    expect(purchases.purchased, PremiumProducts.annual);

    // ---- Switching plans changes the offer ---------------------------

    purchases = _FakePurchases();
    await show(purchases);
    await tester.scrollUntilVisible(find.text('Monthly'), 120);
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();

    // The introductory offer is granted once per Apple ID per subscription
    // group; spending it on the monthly plan sells $4.99 instead of $29.99.
    expect(find.text('Try 3 days free'), findsNothing);
    expect(find.text(r'Subscribe for $4.99/mo'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Lifetime'), 120);
    await tester.tap(find.text('Lifetime'));
    await tester.pumpAndSettle();
    // The one place the word "buy" belongs: it really is a one-off purchase.
    expect(find.text(r'Buy for good — $59.99'), findsOneWidget);

    // Buying is last again — it pops the screen out from under the test.
    await tester.scrollUntilVisible(find.text('Monthly'), 120);
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'Subscribe for $4.99/mo'));
    await tester.pumpAndSettle();
    expect(purchases.purchased, PremiumProducts.monthly);

    // ---- Cancelling is not an error ----------------------------------

    await show(_FakePurchases(result: PurchaseResult.cancelled));
    await tester.tap(find.text('Try 3 days free'));
    await tester.pumpAndSettle();
    expect(
      find.byType(SnackBar),
      findsNothing,
      reason:
          'a user who backed out of the store sheet has not hit a problem, '
          'and saying they have reads as a bug',
    );

    // ---- A real failure is reported ----------------------------------

    await show(_FakePurchases(result: PurchaseResult.failed));
    await tester.tap(find.text('Try 3 days free'));
    await tester.pumpAndSettle();
    expect(find.text('The purchase did not go through'), findsOneWidget);

    // ---- Restoring with nothing to restore says so -------------------

    await show(_FakePurchases());
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to restore on this account'), findsOneWidget);

    // ---- Restoring something closes the paywall ----------------------
    // The user who reinstalled and already paid must not be asked twice.

    await show(_FakePurchases(restorable: true));
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(find.byType(PaywallScreen), findsNothing);
  });
}
