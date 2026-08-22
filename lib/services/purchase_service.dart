import '../models/entitlement.dart';

/// Product identifiers, as they must be registered in App Store Connect and
/// the Play Console. Keep the three in one subscription group on both
/// stores — outside a group, upgrade/downgrade does not work and a user can
/// end up holding two active subscriptions.
///
/// Lifetime is a non-consumable, not a subscription, so it sits outside the
/// group by definition.
class PremiumProducts {
  const PremiumProducts._();

  static const annual = 'com.vovafes.waterapp.premium.annual';
  static const monthly = 'com.vovafes.waterapp.premium.monthly';
  static const lifetime = 'com.vovafes.waterapp.premium.lifetime';

  static const all = [annual, monthly, lifetime];
}

/// A plan as shown on the paywall.
///
/// Prices are *display* strings. They come from the store at runtime in a
/// real implementation, because the store knows the user's storefront,
/// currency and any regional tier — hardcoding "$29.99" ships the wrong
/// number to everyone outside the US.
class PremiumPlan {
  final String productId;
  final PremiumTier tier;
  final String price;

  /// Per-month equivalent, shown under the annual plan. People compare
  /// monthly numbers, not annual ones.
  final String? perMonth;

  /// e.g. "-50%". Null on plans that are not the deal.
  final String? savingBadge;

  /// Free trial length. Only the annual plan carries one: the introductory
  /// offer is granted once per Apple ID per subscription group, and
  /// spending it on the monthly plan sells $4.99 instead of $29.99.
  final Duration? trial;

  const PremiumPlan({
    required this.productId,
    required this.tier,
    required this.price,
    this.perMonth,
    this.savingBadge,
    this.trial,
  });
}

/// Outcome of a purchase attempt, so the paywall can tell "cancelled" apart
/// from "failed" — a user who backed out of the sheet must not be shown an
/// error.
enum PurchaseResult { success, cancelled, failed, unavailable }

/// The store-facing half of Premium.
///
/// Deliberately an interface. The app never trusts what this returns as the
/// final word on access: a successful purchase is reported to the backend,
/// the backend records it against the account, and `/auth/me` hands back
/// the [Entitlement] that actually gates features. This layer only *starts*
/// transactions and restores them.
abstract class PurchaseService {
  /// Plans to show, in paywall order. May hit the network.
  Future<List<PremiumPlan>> plans();

  Future<PurchaseResult> purchase(String productId);

  /// Required by App Review — a paywall without a working Restore is
  /// rejected. Returns true if anything was restored.
  Future<bool> restore();
}

/// What ships until the store products exist.
///
/// There is no App Store Connect app record, no Play listing, and no
/// RevenueCat project yet, so there is nothing to fetch prices from. This
/// implementation serves the planned tiers from MONETIZATION.md §4 for
/// layout and copy work, and refuses to transact.
///
/// Replacing it is one class, not a refactor: implement [PurchaseService]
/// over `purchases_flutter`, register the products, and swap the instance
/// handed to [PaywallScreen].
class UnconfiguredPurchaseService implements PurchaseService {
  const UnconfiguredPurchaseService();

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
  Future<PurchaseResult> purchase(String productId) async =>
      PurchaseResult.unavailable;

  @override
  Future<bool> restore() async => false;
}
