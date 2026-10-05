import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:water_app_mobile/models/entitlement.dart';
import 'package:water_app_mobile/services/purchase_service.dart';
import 'package:water_app_mobile/services/store_purchase_service.dart';

ProductDetails _product(String id, double price) => ProductDetails(
  id: id,
  title: id,
  description: '',
  price: '€${price.toStringAsFixed(2)}',
  rawPrice: price,
  currencyCode: 'EUR',
  currencySymbol: '€',
);

PurchaseDetails _purchase(
  String id,
  PurchaseStatus status, {
  bool pending = true,
}) {
  final p = PurchaseDetails(
    purchaseID: 'txn-1',
    productID: id,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'token-1',
      source: 'test',
    ),
    transactionDate: '0',
    status: status,
  );
  p.pendingCompletePurchase = pending;
  return p;
}

/// Just enough of the plugin for the service: a stream we control and a
/// record of what the service asked it to do.
class _FakeIap extends Fake implements InAppPurchase {
  final controller = StreamController<List<PurchaseDetails>>.broadcast();
  bool available = true;
  Set<String> known = PremiumProducts.all.toSet();
  final completed = <PurchaseDetails>[];
  final bought = <String>[];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: [
          for (final id in ids)
            if (known.contains(id))
              _product(id, id == PremiumProducts.annual ? 29.99 : 4.99),
        ],
        notFoundIDs: [
          for (final id in ids)
            if (!known.contains(id)) id,
        ],
      );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    bought.add(purchaseParam.productDetails.id);
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async =>
      completed.add(purchase);

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}
}

void main() {
  group('pure helpers', () {
    test('ISO periods become durations', () {
      expect(
        StorePurchaseService.parseIsoPeriod('P3D'),
        const Duration(days: 3),
      );
      expect(
        StorePurchaseService.parseIsoPeriod('P1W'),
        const Duration(days: 7),
      );
      expect(
        StorePurchaseService.parseIsoPeriod('P1W3D'),
        const Duration(days: 10),
      );
      expect(
        StorePurchaseService.parseIsoPeriod('P1M'),
        const Duration(days: 30),
      );
      expect(
        StorePurchaseService.parseIsoPeriod('P1Y'),
        const Duration(days: 365),
      );
      expect(StorePurchaseService.parseIsoPeriod('nonsense'), isNull);
      expect(StorePurchaseService.parseIsoPeriod('P0D'), isNull);
    });

    test('backend status decides whether a transaction is finished', () {
      VerifyOutcome o(bool ok, int? s) =>
          StorePurchaseService.outcomeForStatus(ok, s);
      expect(o(true, 200), VerifyOutcome.granted);
      // Transient: keep the transaction so the store redelivers it.
      expect(o(false, 0), VerifyOutcome.retryLater);
      expect(o(false, null), VerifyOutcome.retryLater);
      expect(o(false, 401), VerifyOutcome.retryLater);
      expect(o(false, 429), VerifyOutcome.retryLater);
      expect(o(false, 503), VerifyOutcome.retryLater);
      // The server looked and said no: finish it, do not loop forever.
      expect(o(false, 422), VerifyOutcome.rejected);
      expect(o(false, 403), VerifyOutcome.rejected);
    });

    test('plans use the store prices and derive badge and per-month', () {
      final plans = StorePurchaseService.buildPlans(
        annual: _product(PremiumProducts.annual, 29.99),
        monthly: _product(PremiumProducts.monthly, 4.99),
        lifetime: _product(PremiumProducts.lifetime, 59.99),
      );
      expect(plans.map((p) => p.tier), [
        PremiumTier.annual,
        PremiumTier.monthly,
        PremiumTier.lifetime,
      ]);
      expect(plans.first.price, '€29.99');
      expect(plans.first.perMonth, '€2.50');
      expect(plans.first.savingBadge, '-50%');
      // A plain ProductDetails carries no trial info: never invent one.
      expect(plans.first.trial, isNull);
    });
  });

  group('service flow', () {
    late _FakeIap iap;
    late List<PurchaseDetails> verified;
    late VerifyOutcome outcome;
    late int refreshed;
    late StorePurchaseService service;

    setUp(() {
      iap = _FakeIap();
      verified = [];
      outcome = VerifyOutcome.granted;
      refreshed = 0;
      service = StorePurchaseService(
        iap: iap,
        verifier: (p) async {
          verified.add(p);
          return outcome;
        },
        onEntitlementMayHaveChanged: () => refreshed++,
      )..start();
    });

    tearDown(() => service.dispose());

    Future<void> deliver(PurchaseDetails p) async {
      iap.controller.add([p]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test(
      'before the products exist the paywall is shown but cannot charge',
      () async {
        iap.known = {};
        final plans = await service.plans();
        expect(plans, hasLength(3)); // planned tiers, for layout
        expect(
          await service.purchase(PremiumProducts.annual),
          PurchaseResult.unavailable,
        );
        expect(iap.bought, isEmpty);
      },
    );

    test('a store that is not available falls back the same way', () async {
      iap.available = false;
      expect(await service.plans(), hasLength(3));
      expect(
        await service.purchase(PremiumProducts.annual),
        PurchaseResult.unavailable,
      );
    });

    test(
      'purchase: store says purchased, backend grants, transaction finished',
      () async {
        await service.plans();
        final result = service.purchase(PremiumProducts.annual);
        await Future<void>.delayed(Duration.zero);
        expect(iap.bought, [PremiumProducts.annual]);

        final p = _purchase(PremiumProducts.annual, PurchaseStatus.purchased);
        await deliver(p);

        expect(await result, PurchaseResult.success);
        expect(verified, [p]);
        expect(iap.completed, [p]);
        // Someone was waiting, so the paywall refreshes; the callback is for
        // purchases nobody was waiting on.
        expect(refreshed, 0);
      },
    );

    test(
      'a user who backs out of the sheet is "cancelled", not an error',
      () async {
        await service.plans();
        final result = service.purchase(PremiumProducts.annual);
        await Future<void>.delayed(Duration.zero);
        await deliver(
          _purchase(
            PremiumProducts.annual,
            PurchaseStatus.canceled,
            pending: false,
          ),
        );
        expect(await result, PurchaseResult.cancelled);
        expect(verified, isEmpty);
      },
    );

    test(
      'backend unreachable: purchase fails but the transaction stays open',
      () async {
        outcome = VerifyOutcome.retryLater;
        await service.plans();
        final result = service.purchase(PremiumProducts.monthly);
        await Future<void>.delayed(Duration.zero);
        await deliver(
          _purchase(PremiumProducts.monthly, PurchaseStatus.purchased),
        );

        expect(await result, PurchaseResult.failed);
        // Not finished: the store redelivers it next launch, which is the retry.
        expect(iap.completed, isEmpty);
      },
    );

    test(
      'backend rejection finishes the transaction instead of looping',
      () async {
        outcome = VerifyOutcome.rejected;
        await service.plans();
        final result = service.purchase(PremiumProducts.monthly);
        await Future<void>.delayed(Duration.zero);
        await deliver(
          _purchase(PremiumProducts.monthly, PurchaseStatus.purchased),
        );

        expect(await result, PurchaseResult.failed);
        expect(iap.completed, hasLength(1));
      },
    );

    test(
      'a transaction redelivered at launch is granted and refreshes the app',
      () async {
        // No purchase() call: this is last session's interrupted purchase.
        await deliver(
          _purchase(PremiumProducts.annual, PurchaseStatus.purchased),
        );

        expect(verified, hasLength(1));
        expect(iap.completed, hasLength(1));
        expect(refreshed, 1);
      },
    );

    test(
      'pending (ask-to-buy) does nothing until the store resolves it',
      () async {
        await deliver(
          _purchase(
            PremiumProducts.annual,
            PurchaseStatus.pending,
            pending: false,
          ),
        );
        expect(verified, isEmpty);
        expect(iap.completed, isEmpty);
        expect(refreshed, 0);
      },
    );
  });
}
