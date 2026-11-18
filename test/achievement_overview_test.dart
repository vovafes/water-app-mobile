import 'package:flutter_test/flutter_test.dart';
import 'package:water_app_mobile/models/achievement.dart';

/// The achievements screen reads one response: groups of ladders, the next
/// goal and the totals. An older backend sends only the flat list, and the
/// screen has to keep working with that.
void main() {
  Map<String, dynamic> row(
    int id,
    String slug, {
    bool unlocked = false,
    int current = 0,
    int target = 3,
    String state = 'locked',
    String? unit,
  }) => {
    'id': id,
    'slug': slug,
    'name': slug,
    'description': 'd',
    'points': 10,
    'unlocked': unlocked,
    'current': current,
    'target': target,
    'percent': target == 0 ? 0 : (current / target * 100).floor(),
    'state': state,
    'unit': unit,
  };

  test('reads groups, next goal and summary', () {
    final o = AchievementOverview.fromJson({
      'summary': {'unlocked': 1, 'total': 3, 'points': 10},
      'next': {
        ...row(2, 'streak-7', current: 5, target: 7, state: 'current'),
        'group_title': 'Streaks',
      },
      'groups': [
        {
          'key': 'streak',
          'title': 'Streaks',
          'items': [
            row(1, 'streak-3', unlocked: true, current: 3, state: 'done'),
            row(2, 'streak-7', current: 5, target: 7, state: 'current'),
            row(3, 'streak-14'),
          ],
        },
      ],
    });

    expect(o.total, 3);
    expect(o.points, 10);
    expect(o.groups.single.title, 'Streaks');
    expect(o.groups.single.unlockedCount, 1);
    expect(o.groups.single.items.map((a) => a.state), [
      'done',
      'current',
      'locked',
    ]);
    expect(o.next!.slug, 'streak-7');
    expect(o.nextGroup, 'Streaks');
    expect(o.next!.percent, 71);
  });

  test('an older backend with only the flat list still works', () {
    final o = AchievementOverview.fromJson({
      'achievements': [
        {
          'id': 1,
          'name': 'a',
          'description': 'd',
          'points': 20,
          'unlocked': true,
        },
        {
          'id': 2,
          'name': 'b',
          'description': 'd',
          'points': 5,
          'unlocked': false,
        },
      ],
    });

    expect(o.groups, hasLength(1));
    expect(o.total, 2);
    expect(o.unlocked, 1);
    expect(o.points, 20);
    expect(o.next, isNull);
    expect(o.groups.single.items.map((a) => a.state), ['done', 'locked']);
  });

  test('an empty or broken response is an empty overview, not a crash', () {
    final o = AchievementOverview.fromJson({});
    expect(o.groups, isEmpty);
    expect(o.total, 0);
    expect(o.next, isNull);
  });

  test('progress labels: plain counts and millilitres', () {
    String fmt(int n) => n.toString();
    final days = Achievement.fromJson(row(1, 'a', current: 4, target: 10));
    final volume = Achievement.fromJson(
      row(2, 'b', current: 4200, target: 10000, unit: 'ml'),
    );

    expect(days.progressLabel(fmt, 'ml'), '4 / 10');
    expect(volume.progressLabel(fmt, 'ml'), '4200 / 10000 ml');
  });

  test(
    'a target of zero is read as one, so a bar can never divide by zero',
    () {
      expect(Achievement.fromJson(row(1, 'a', target: 0)).target, 1);
    },
  );
}
