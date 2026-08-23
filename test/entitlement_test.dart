import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:water_app_mobile/models/entitlement.dart';
import 'package:water_app_mobile/premium/premium_gate.dart';

void main() {
  Entitlement inDays(int days, {PremiumTier tier = PremiumTier.annual}) =>
      Entitlement(
        tier: tier,
        expiresAt: DateTime.now().add(Duration(days: days)),
      );

  group('Entitlement.isActive', () {
    test('a backend that sends no entitlement key means free', () {
      // The whole point of parsing an absent field to `free` rather than
      // throwing: the backend does not send this yet, and every build in
      // the wild before it does must read as unsubscribed.
      expect(Entitlement.fromJson(const {}).isActive, isFalse);
      expect(Entitlement.free.isActive, isFalse);
    });

    test('an unexpired subscription is active', () {
      expect(inDays(30).isActive, isTrue);
    });

    test('an expired one is not', () {
      expect(inDays(-1).isActive, isFalse);
    });

    test('lifetime has no expiry and stays active', () {
      const forever = Entitlement(tier: PremiumTier.lifetime);
      expect(forever.isActive, isTrue);
    });

    test('a non-lifetime tier with no expiry is treated as expired', () {
      // A subscription the backend cannot put a date on is not one to
      // trust. Failing open here would hand out Premium on a malformed
      // payload.
      const undated = Entitlement(tier: PremiumTier.annual);
      expect(undated.isActive, isFalse);
    });

    test('grace period keeps access after expiry', () {
      // Both stores retry a failed payment for up to 16 days, and the card
      // usually goes through. Cutting access at the first bank decline
      // loses paying users.
      final dunning = Entitlement(
        tier: PremiumTier.annual,
        expiresAt: DateTime.now().subtract(const Duration(days: 2)),
        inGraceUntil: DateTime.now().add(const Duration(days: 5)),
      );
      expect(dunning.isActive, isTrue);
      expect(dunning.isInGrace, isTrue);
    });

    test('a cancelled subscription keeps access until it expires', () {
      // Cancelling turns off renewal, not the current period. Cutting it
      // short is what generates refund requests.
      final cancelled = Entitlement(
        tier: PremiumTier.annual,
        expiresAt: DateTime.now().add(const Duration(days: 40)),
        cancelled: true,
      );
      expect(cancelled.isActive, isTrue);
    });
  });

  group('round trip', () {
    test('survives the offline cache', () {
      final original = inDays(90, tier: PremiumTier.monthly);
      final restored = Entitlement.fromJson(original.toJson());

      expect(restored.tier, PremiumTier.monthly);
      expect(restored.isActive, isTrue);
      expect(
        restored.expiresAt!.difference(original.expiresAt!).inSeconds.abs(),
        lessThan(1),
      );
    });

    test('an unknown tier from a newer backend reads as free', () {
      final e = Entitlement.fromJson(const {'tier': 'quarterly'});
      expect(e.tier, isNull);
      expect(e.isActive, isFalse);
    });
  });

  group('PremiumGate', () {
    const free = PremiumGate(Entitlement.free);
    final paid = PremiumGate(inDays(30));

    test('free users get the documented limits', () {
      expect(free.historyDayLimit, FreeLimits.historyDays);
      expect(free.reminderLimit, FreeLimits.reminders);
      expect(free.allowsAchievementAt(FreeLimits.achievements), isFalse);
      expect(free.allowsAchievementAt(0), isTrue);
    });

    test('premium users get no limits at all', () {
      expect(paid.historyDayLimit, isNull);
      expect(paid.reminderLimit, isNull);
      expect(paid.allowsAchievementAt(999), isTrue);
    });

    test('the free drink set is water, tea and coffee', () {
      expect(free.allowsDrink('water'), isTrue);
      expect(free.allowsDrink('coffee'), isTrue);
      expect(free.allowsDrink('beer'), isFalse);
      expect(paid.allowsDrink('beer'), isTrue);
    });

    test('a drink with no slug is allowed rather than locked', () {
      // The backend omits `drink_slug` on log listings (TODO.md), so
      // failing closed would lock drinks the user can already log.
      expect(free.allowsDrink(null), isTrue);
    });
  });

  group('PremiumFeature.healthSync names the right platform', () {
    // The one paywall string that differs per platform. Promising an
    // Android user Apple Health sells software their phone cannot run,
    // which on a paid screen is a refund rather than a typo.
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('Android is offered Health Connect', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(PremiumFeature.healthSync.prompt, contains('Health Connect'));
    });

    test('iOS is offered Apple Health', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(PremiumFeature.healthSync.prompt, contains('Apple Health'));
    });
  });
}
