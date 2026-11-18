import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:water_app_mobile/models/achievement.dart';
import 'package:water_app_mobile/theme.dart';
import 'package:water_app_mobile/widgets/achievement_badge.dart';

/// The badge says how rare an achievement is with rings (none, one, two) and
/// where you are with its fill. A freshly unlocked one fills once, with no
/// bounce, and not at all when the system asks for reduced motion.
void main() {
  Achievement make({
    int tier = 1,
    bool unlocked = true,
    String state = 'done',
    bool isNew = false,
  }) => Achievement(
    id: 1,
    name: 'x',
    description: 'x',
    iconKey: 'flame',
    unlocked: unlocked,
    state: state,
    tier: tier,
    isNew: isNew,
  );

  Widget host(
    Achievement a, {
    bool animate = false,
    bool reduceMotion = false,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: Center(
          child: AchievementBadge(achievement: a, animate: animate),
        ),
      ),
    ),
  );

  int circles(WidgetTester t) => t
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(AchievementBadge),
          matching: find.byType(DecoratedBox),
        ),
      )
      .length;

  Color fill(WidgetTester t) {
    final box = t.widget<Container>(
      find
          .descendant(
            of: find.byType(AchievementBadge),
            matching: find.byType(Container),
          )
          .first,
    );
    return (box.decoration! as BoxDecoration).color!;
  }

  group('model', () {
    test('reads is_new and tier', () {
      final a = Achievement.fromJson({
        'id': 1,
        'name': 'a',
        'description': 'd',
        'unlocked': true,
        'is_new': true,
        'tier': 3,
      });
      expect(a.isNew, isTrue);
      expect(a.tier, 3);
    });

    test('an older backend sends neither: not new, everyday tier', () {
      final a = Achievement.fromJson({
        'id': 1,
        'name': 'a',
        'description': 'd',
        'unlocked': true,
      });
      expect(a.isNew, isFalse);
      expect(a.tier, 1);
    });

    test('a nonsense tier is kept in range', () {
      expect(
        Achievement.fromJson({
          'id': 1,
          'name': 'a',
          'description': 'd',
          'unlocked': false,
          'tier': 99,
        }).tier,
        3,
      );
      expect(
        Achievement.fromJson({
          'id': 1,
          'name': 'a',
          'description': 'd',
          'unlocked': false,
          'tier': -4,
        }).tier,
        1,
      );
    });
  });

  group('rings', () {
    testWidgets('an everyday badge has none, a milestone one, a rare one two', (
      t,
    ) async {
      await t.pumpWidget(host(make(tier: 1)));
      expect(circles(t), 1);
      await t.pumpWidget(host(make(tier: 2)));
      expect(circles(t), 2);
      await t.pumpWidget(host(make(tier: 3)));
      expect(circles(t), 3);
    });
  });

  group('fill', () {
    testWidgets('reached is amber, ahead is muted', (t) async {
      await t.pumpWidget(host(make()));
      expect(fill(t), BrandColors.amber500);

      await t.pumpWidget(host(make(unlocked: false, state: 'locked')));
      expect(fill(t), isNot(BrandColors.amber500));
    });
  });

  group('unlock animation', () {
    testWidgets('starts looking locked, then fills to amber', (t) async {
      await t.pumpWidget(host(make(isNew: true), animate: true));

      expect(
        fill(t),
        isNot(BrandColors.amber500),
        reason: 'it begins as a locked badge',
      );

      // The short delay, then the fill (650 ms).
      await t.pump(AchievementBadge.delay + const Duration(milliseconds: 100));
      final midway = fill(t);
      expect(midway, isNot(BrandColors.amber500));

      await t.pump(const Duration(seconds: 1));
      expect(fill(t), BrandColors.amber500);
    });

    testWidgets('does not overshoot: the badge never grows past its size', (
      t,
    ) async {
      await t.pumpWidget(host(make(isNew: true), animate: true));

      var largest = 0.0;
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 40));
        final scale = t
            .widget<Transform>(
              find
                  .descendant(
                    of: find.byType(AchievementBadge),
                    matching: find.byType(Transform),
                  )
                  .first,
            )
            .transform
            .getMaxScaleOnAxis();
        if (scale > largest) largest = scale;
      }

      expect(largest, lessThanOrEqualTo(1.0 + 1e-9));
    });

    testWidgets('a badge that is not new shows its state straight away', (
      t,
    ) async {
      await t.pumpWidget(host(make()));

      expect(fill(t), BrandColors.amber500);
    });

    testWidgets('reduced motion: no animation, the real state at once', (
      t,
    ) async {
      await t.pumpWidget(
        host(make(isNew: true), animate: true, reduceMotion: true),
      );

      expect(fill(t), BrandColors.amber500);
    });

    testWidgets('turning animate on later plays it then', (t) async {
      await t.pumpWidget(host(make()));
      expect(fill(t), BrandColors.amber500);

      await t.pumpWidget(host(make(isNew: true), animate: true));
      expect(fill(t), isNot(BrandColors.amber500));

      // The delay fires on the first pump, the fill runs over the next ones.
      await t.pump(AchievementBadge.delay + const Duration(milliseconds: 50));
      await t.pump(const Duration(seconds: 1));
      expect(fill(t), BrandColors.amber500);
    });
  });
}
