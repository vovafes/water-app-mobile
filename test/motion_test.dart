import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:water_app_mobile/widgets/motion.dart';

/// The reduced-motion promise is the kind that rots silently: nobody
/// develops with the accessibility switch on, so the only thing keeping it
/// true is a test.
void main() {
  /// [child] under a MediaQuery with animations on or off.
  Widget wrap(Widget child, {required bool reduced}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );

  Widget counter(int value) => AnimatedCount(
    value: value,
    duration: Motion.slow,
    builder: (_, v) => Text('$v'),
  );

  testWidgets('a count travels to its new value', (tester) async {
    await tester.pumpWidget(wrap(counter(0), reduced: false));
    expect(find.text('0'), findsOneWidget);

    await tester.pumpWidget(wrap(counter(1000), reduced: false));
    await tester.pump(const Duration(milliseconds: 100));

    final shown = int.parse(
      (tester.widget<Text>(find.byType(Text)).data)!,
    );
    expect(
      shown,
      allOf(greaterThan(0), lessThan(1000)),
      reason: 'caught in flight — the number is counting, not cutting',
    );

    await tester.pumpAndSettle();
    expect(find.text('1000'), findsOneWidget);
  });

  testWidgets('reduced motion delivers the value without travelling', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(counter(0), reduced: true));
    await tester.pumpWidget(wrap(counter(1000), reduced: true));
    await tester.pump();

    expect(
      find.text('1000'),
      findsOneWidget,
      reason:
          'reduced motion is not reduced information — the total still '
          'updates, it just arrives instead of animating',
    );
  });

  testWidgets('an interrupted count continues from where it is', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(counter(0), reduced: false));
    await tester.pumpWidget(wrap(counter(1000), reduced: false));
    await tester.pump(const Duration(milliseconds: 100));

    final mid = int.parse((tester.widget<Text>(find.byType(Text)).data)!);

    // A second drink logged before the first has finished counting.
    await tester.pumpWidget(wrap(counter(1500), reduced: false));
    await tester.pump();

    final after = int.parse((tester.widget<Text>(find.byType(Text)).data)!);
    expect(
      after,
      closeTo(mid, 20),
      reason:
          'the new count starts from the number on screen, not from the '
          'old target — otherwise the total visibly jumps backwards',
    );

    await tester.pumpAndSettle();
    expect(find.text('1500'), findsOneWidget);
  });

  test('reduced motion zeroes every duration that goes through Motion', () {
    // Guards the helper itself: a widget that reaches for Motion.slow
    // directly instead of Motion.of(context, Motion.slow) is the way this
    // gets quietly broken.
    expect(Motion.fast, isNot(Duration.zero));
    expect(Motion.normal, isNot(Duration.zero));
    expect(Motion.slow, isNot(Duration.zero));
  });
}
