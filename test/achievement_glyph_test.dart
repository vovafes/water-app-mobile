import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:water_app_mobile/models/achievement.dart';
import 'package:water_app_mobile/widgets/achievement_glyph.dart';

/// Built-in achievements are drawn from `icon_key`; one an admin added has no
/// key and keeps its emoji. Neither a blank tile nor a raw key may ever show.
void main() {
  Achievement make({String? icon, String? key, bool unlocked = false}) =>
      Achievement(
        id: 1,
        name: 'x',
        description: 'x',
        icon: icon,
        iconKey: key,
        unlocked: unlocked,
      );

  Future<void> show(WidgetTester t, Achievement a) => t.pumpWidget(
    MaterialApp(
      home: AchievementGlyph(achievement: a, size: 28, color: Colors.black),
    ),
  );

  // The same vocabulary the backend's AchievementIcons::KEYS defines.
  const keys = [
    'drop',
    'flame',
    'bolt',
    'trophy',
    'badge',
    'calendar',
    'star',
    'trend',
    'scale',
    'pencil',
    'book',
    'archive',
    'stack',
    'globe',
    'swatch',
    'map',
    'puzzle',
    'sun',
    'moon',
  ];

  for (final key in keys) {
    testWidgets('key "$key" draws an icon, not the emoji', (t) async {
      await show(t, make(icon: '🔥', key: key));
      expect(find.byType(Icon), findsOneWidget);
      expect(find.text('🔥'), findsNothing);
    });
  }

  testWidgets('an admin-added achievement keeps its emoji', (t) async {
    await show(t, make(icon: '🎯'));
    expect(find.text('🎯'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('an unknown key falls back to the emoji', (t) async {
    await show(t, make(icon: '🎯', key: 'from-the-future'));
    expect(find.text('🎯'), findsOneWidget);
  });

  testWidgets('no icon at all: trophy when unlocked, lock when locked', (
    t,
  ) async {
    await show(t, make(unlocked: true));
    expect(tester(t).icon, Icons.emoji_events_rounded);
    await show(t, make());
    expect(tester(t).icon, Icons.lock_outline_rounded);
  });
}

Icon tester(WidgetTester t) => t.widget<Icon>(find.byType(Icon));
