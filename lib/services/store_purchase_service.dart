import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

import '../models/entitlement.dart';
import 'api_service.dart';
import 'purchase_service.dart';

/// What the backend made of a purchase the store reported.
enum VerifyOutcome {
  /// Recorded; the account is Premium. Safe to finish the transaction.
  granted,

  /// The backend (and so the store) refused it: unknown to the store,
  /// owned by another account, wrong product. Retrying will not help, so the
  /// transaction is finished instead of being redelivered at every launch.
  rejected,

  /// Backend or store unreachable. Leave the transaction open: the store
  /// redelivers it on the next launch, and that is the retry.
  retryLater,
}

/// Tells the backend about a purchase and reports what happened.
typedef PurchaseVerifier = Future<VerifyOutcome> Function(PurchaseDetails p);

/// Real store billing through `in_app_purchase` (StoreKit / Play Billing).
///
/// The store only *starts* and *restores* transactions here. Access is
/// decided by the backend: every purchase is posted to
/// `/subscriptions/verify`, the server asks Apple/Google itself, and the app
/// then re-reads `/auth/me` (see [onEntitlementMayHaveChanged]).
///
/// Until the products exist in the consoles, [plans] returns the planned
/// tiers from [UnconfiguredPurchaseService] and [purchase] reports
/// [PurchaseResult.unavailable] — so a build that ships before the store
/// setup is done shows a paywall that cannot charge, rather than one that
/// crashes or invents prices.
class StorePurchaseService implements PurchaseService {
  final InAppPurchase _iap;
  final PurchaseVerifier _verify;

  /// Called after a purchase was granted outside a paywall interaction
  /// (ask-to-buy approval, a transaction interrupted last session). The root
  /// of the app uses it to refresh the entitlement.
  final VoidCallback? onEntitlementMayHaveChanged;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _live = false;

  /// Waiters for the next result of a given product (a purchase in flight).
  final Map<String, Completer<PurchaseResult>> _inFlight = {};

  /// Restore reports through the same stream; this collects its results.
  Completer<bool>? _restoring;
  int _restoredGranted = 0;

  StorePurchaseService({
    InAppPurchase? iap,
    PurchaseVerifier? verifier,
    this.onEntitlementMayHaveChanged,
  }) : _iap = iap ?? InAppPurchase.instance,
       _verify = verifier ?? verifyWithBackend;

  /// Start listening. Must happen at app launch, not when the paywall opens:
  /// a purchase interrupted last session is redelivered on this stream, and
  /// an unfinished transaction is refunded by Google after three days.
  void start() {
    _sub ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('purchaseStream error: $e'),
    );
  }

  void dispose() => _sub?.cancel();

  @override
  Future<List<PremiumPlan>> plans() async {
    const fallback = UnconfiguredPurchaseService();
    try {
      if (!await _iap.isAvailable()) return fallback.plans();
      final res = await _iap.queryProductDetails(PremiumProducts.all.toSet());
      final byId = {for (final d in res.productDetails) d.id: d};
      // All three or nothing: a half-configured store would show a paywall
      // with a missing plan and a wrong "-50%".
      if (!PremiumProducts.all.every(byId.containsKey)) {
        _live = false;
        return fallback.plans();
      }
      _live = true;
      return buildPlans(
        annual: byId[PremiumProducts.annual]!,
        monthly: byId[PremiumProducts.monthly]!,
        lifetime: byId[PremiumProducts.lifetime]!,
      );
    } catch (e) {
      debugPrint('plans() failed: $e');
      _live = false;
      return fallback.plans();
    }
  }

  @override
  Future<PurchaseResult> purchase(String productId) async {
    if (!_live) return PurchaseResult.unavailable;
    if (_inFlight.containsKey(productId)) return PurchaseResult.failed;

    final res = await _iap.queryProductDetails({productId});
    if (res.productDetails.isEmpty) return PurchaseResult.unavailable;

    final waiter = _inFlight[productId] = Completer<PurchaseResult>();
    try {
      // The plugin buys subscriptions through buyNonConsumable as well; the
      // difference between the two lives in the store product, not here.
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: res.productDetails.first),
      );
      if (!started) return PurchaseResult.failed;
      return await waiter.future.timeout(const Duration(minutes: 10));
    } on TimeoutException {
      return PurchaseResult.failed;
    } catch (e) {
      debugPrint('purchase failed: $e');
      return PurchaseResult.failed;
    } finally {
      _inFlight.remove(productId);
    }
  }

  @override
  Future<bool> restore() async {
    if (!await _iap.isAvailable()) return false;
    _restoredGranted = 0;
    final done = _restoring = Completer<bool>();
    try {
      await _iap.restorePurchases();
      // Neither store signals "restore finished" on the stream. Collect for a
      // short window; whatever arrived by then is the answer.
      await Future<void>.delayed(const Duration(seconds: 6));
      if (!done.isCompleted) done.complete(_restoredGranted > 0);
      return done.future;
    } catch (e) {
      debugPrint('restore failed: $e');
      return false;
    } finally {
      _restoring = null;
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break; // Ask-to-buy / slow payment: wait for the next event.
        case PurchaseStatus.canceled:
          _finish(p.productID, PurchaseResult.cancelled);
        case PurchaseStatus.error:
          _finish(p.productID, PurchaseResult.failed);
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _grant(p);
      }
    }
  }

  Future<void> _grant(PurchaseDetails p) async {
    final outcome = await _verify(p);
    final wasWaiting = _inFlight.containsKey(p.productID);

    // Finish the transaction unless the failure is worth a redelivery.
    if (outcome != VerifyOutcome.retryLater && p.pendingCompletePurchase) {
      await _iap.completePurchase(p);
    }

    if (outcome == VerifyOutcome.granted &&
        p.status == PurchaseStatus.restored) {
      _restoredGranted++;
    }

    _finish(p.productID, switch (outcome) {
      VerifyOutcome.granted => PurchaseResult.success,
      _ => PurchaseResult.failed,
    });

    // Nobody was waiting: this came from a previous session or an approval.
    if (outcome == VerifyOutcome.granted && !wasWaiting && _restoring == null) {
      onEntitlementMayHaveChanged?.call();
    }
  }

  void _finish(String productId, PurchaseResult result) {
    final w = _inFlight[productId];
    if (w != null && !w.isCompleted) w.complete(result);
  }

  /// POSTs the purchase to the backend. Apple identifies a purchase by its
  /// transaction id (`purchaseID`); Google by the purchase token, which is
  /// the `serverVerificationData` — and Google also needs the product id.
  @visibleForTesting
  static Future<VerifyOutcome> verifyWithBackend(PurchaseDetails p) async {
    final apple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final reference = apple
        ? (p.purchaseID ?? '')
        : p.verificationData.serverVerificationData;
    if (reference.isEmpty) return VerifyOutcome.rejected;

    final res = await ApiService.post('/subscriptions/verify', {
      'store': apple ? 'app_store' : 'play_store',
      'reference': reference,
      'product_id': p.productID,
    });
    return outcomeForStatus(res['success'] == true, res['status'] as int?);
  }

  /// 2xx → granted; 5xx / no connection / 401 / 429 → try again later; any other
  /// 4xx → the server looked at it and said no.
  @visibleForTesting
  static VerifyOutcome outcomeForStatus(bool success, int? status) {
    if (success) return VerifyOutcome.granted;
    final s = status ?? 0;
    // 401: not signed in (yet) — the transaction must survive until we are.
    if (s == 0 || s == 401 || s == 429 || s >= 500) {
      return VerifyOutcome.retryLater;
    }
    return VerifyOutcome.rejected;
  }

  /// Turns three store products into paywall plans. Prices are the store's
  /// own strings (storefront currency, tax included); only the per-month
  /// figure and the saving badge are computed, and from raw prices in the
  /// same currency.
  @visibleForTesting
  static List<PremiumPlan> buildPlans({
    required ProductDetails annual,
    required ProductDetails monthly,
    required ProductDetails lifetime,
  }) {
    String? badge;
    if (monthly.rawPrice > 0) {
      final saving = (1 - annual.rawPrice / (monthly.rawPrice * 12)) * 100;
      if (saving >= 1) badge = '-${saving.round()}%';
    }
    final perMonth = annual.rawPrice > 0
        ? '${annual.currencySymbol}${(annual.rawPrice / 12).toStringAsFixed(2)}'
        : null;

    return [
      PremiumPlan(
        productId: annual.id,
        tier: PremiumTier.annual,
        price: annual.price,
        perMonth: perMonth,
        savingBadge: badge,
        trial: freeTrialOf(annual),
      ),
      PremiumPlan(
        productId: monthly.id,
        tier: PremiumTier.monthly,
        price: monthly.price,
      ),
      PremiumPlan(
        productId: lifetime.id,
        tier: PremiumTier.lifetime,
        price: lifetime.price,
      ),
    ];
  }

  /// The free-trial length the *store* will actually grant, or null.
  ///
  /// Read from the store product instead of hardcoded so the paywall never
  /// promises a trial that is not configured. Caveat on iOS: StoreKit 1 does
  /// not say whether *this* Apple ID already used its introductory offer, so
  /// a returning user can still be shown a trial that Apple then declines.
  @visibleForTesting
  static Duration? freeTrialOf(ProductDetails d) {
    if (d is AppStoreProductDetails) {
      final intro = d.skProduct.introductoryPrice;
      if (intro == null || double.tryParse(intro.price) != 0) return null;
      final n = intro.subscriptionPeriod.numberOfUnits * intro.numberOfPeriods;
      return switch (intro.subscriptionPeriod.unit) {
        SKSubscriptionPeriodUnit.day => Duration(days: n),
        SKSubscriptionPeriodUnit.week => Duration(days: 7 * n),
        SKSubscriptionPeriodUnit.month => Duration(days: 30 * n),
        SKSubscriptionPeriodUnit.year => Duration(days: 365 * n),
      };
    }
    if (d is GooglePlayProductDetails) {
      final offers = d.productDetails.subscriptionOfferDetails;
      final i = d.subscriptionIndex;
      if (offers == null || i == null || i >= offers.length) return null;
      for (final phase in offers[i].pricingPhases) {
        if (phase.priceAmountMicros == 0) {
          return parseIsoPeriod(phase.billingPeriod);
        }
      }
    }
    return null;
  }

  /// `P3D`, `P1W`, `P1M`, `P1Y` and combinations like `P1W3D`.
  @visibleForTesting
  static Duration? parseIsoPeriod(String iso) {
    final m = RegExp(
      r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$',
    ).firstMatch(iso);
    if (m == null) return null;
    int g(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
    final days = g(1) * 365 + g(2) * 30 + g(3) * 7 + g(4);
    return days == 0 ? null : Duration(days: days);
  }

  /// Whether the platform has a store at all (false on desktop/web builds).
  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}
