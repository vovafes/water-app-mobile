import 'package:flutter_test/flutter_test.dart';
import 'package:water_app_mobile/models/reminder.dart';

void main() {
  group('minutesOfDay / formatHm', () {
    test('round-trips a wall-clock string', () {
      expect(minutesOfDay('00:00'), 0);
      expect(minutesOfDay('07:30'), 450);
      expect(minutesOfDay('23:59'), 1439);
      expect(formatHm(450), '07:30');
      expect(formatHm(0), '00:00');
    });

    test('wraps past midnight and rejects junk', () {
      expect(formatHm(1440), '00:00');
      expect(minutesOfDay(null), isNull);
      expect(minutesOfDay('noon'), isNull);
      expect(minutesOfDay('12'), isNull);
    });
  });

  group('Reminder.fromJson', () {
    test('reads the shape the API actually returns', () {
      final r = Reminder.fromJson({
        'id': 7,
        'title': 'Drink up',
        'type': 'interval',
        'interval_minutes': 90,
        'fixed_times': null,
        'quiet_hours_start': '22:00',
        'quiet_hours_end': '07:00',
        'days_of_week': [1, 2, 3, 4, 5],
        'channel': 'push',
        'is_active': true,
      });

      expect(r.id, 7);
      expect(r.type, ReminderType.interval);
      expect(r.intervalMinutes, 90);
      expect(r.fixedTimes, isEmpty);
      expect(r.quietHoursStart, '22:00');
      expect(r.daysOfWeek, [1, 2, 3, 4, 5]);
      expect(r.isActive, isTrue);
    });

    test('tolerates HH:mm:ss and ISO timestamps from the time cast', () {
      final r = Reminder.fromJson({
        'id': 1,
        'type': 'fixed',
        'fixed_times': ['13:30:00', '2026-01-01T08:00:00.000000Z', '08:00'],
        'quiet_hours_start': '22:00:00',
      });

      // Duplicates collapse and the list comes back sorted.
      expect(r.fixedTimes, ['08:00', '13:30']);
      expect(r.quietHoursStart, '22:00');
      expect(r.quietHoursEnd, isNull);
    });

    test('clamps the interval to the range the backend validates', () {
      expect(
        Reminder.fromJson({'id': 1, 'interval_minutes': 5}).intervalMinutes,
        15,
      );
      expect(
        Reminder.fromJson({'id': 1, 'interval_minutes': 5000}).intervalMinutes,
        720,
      );
    });

    test('drops out-of-range weekdays and sorts the rest', () {
      final r = Reminder.fromJson({
        'id': 1,
        'days_of_week': [7, 0, 3, 3, 9, '2'],
      });
      expect(r.daysOfWeek, [2, 3, 7]);
    });

    test('falls back to sane defaults for a sparse row', () {
      final r = Reminder.fromJson({'id': 4});
      expect(r.title, 'Time to drink water');
      expect(r.type, ReminderType.interval);
      expect(r.intervalMinutes, 90);
      expect(r.channel, 'push');
      expect(r.isActive, isTrue);
      expect(r.daysOfWeek, isEmpty);
    });

    test('treats 0 and false alike for is_active', () {
      expect(Reminder.fromJson({'id': 1, 'is_active': 0}).isActive, isFalse);
      expect(
        Reminder.fromJson({'id': 1, 'is_active': false}).isActive,
        isFalse,
      );
      expect(Reminder.fromJson({'id': 1, 'is_active': 1}).isActive, isTrue);
    });

    test('maps the smart type the web app can create', () {
      expect(
        Reminder.fromJson({'id': 1, 'type': 'smart'}).type,
        ReminderType.smart,
      );
      expect(
        Reminder.fromJson({'id': 1, 'type': 'nonsense'}).type,
        ReminderType.interval,
      );
    });
  });

  test('toJson uses the keys the controller validates', () {
    final json = _reminder(
      quietStart: '22:00',
      quietEnd: '07:00',
      days: [1, 5],
    ).toJson();

    expect(
      json.keys,
      containsAll(<String>[
        'title',
        'type',
        'interval_minutes',
        'fixed_times',
        'quiet_hours_start',
        'quiet_hours_end',
        'days_of_week',
        'channel',
        'is_active',
      ]),
    );
    expect(json['type'], 'interval');
    expect(json['quiet_hours_start'], '22:00');
    expect(json['days_of_week'], [1, 5]);
  });

  test('copyWith can null out quiet hours', () {
    final r = _reminder(quietStart: '22:00', quietEnd: '07:00');

    expect(r.copyWith(clearQuietHours: true).hasQuietHours, isFalse);
    expect(r.copyWith(title: 'Renamed').quietHoursStart, '22:00');
  });

  test('everyDay covers both wire spellings of "all week"', () {
    expect(_reminder(days: []).everyDay, isTrue);
    expect(_reminder(days: [1, 2, 3, 4, 5, 6, 7]).everyDay, isTrue);
    expect(_reminder(days: [1, 5]).everyDay, isFalse);
  });

  group('isQuietAt', () {
    test('is always false without a window', () {
      final r = _reminder();
      expect(r.hasQuietHours, isFalse);
      expect(r.isQuietAt(0), isFalse);
      expect(r.isQuietAt(3 * 60), isFalse);
    });

    test('handles a window that wraps past midnight', () {
      final r = _reminder(quietStart: '22:00', quietEnd: '07:00');

      expect(r.isQuietAt(22 * 60), isTrue); // start is inclusive
      expect(r.isQuietAt(23 * 60), isTrue);
      expect(r.isQuietAt(0), isTrue);
      expect(r.isQuietAt(6 * 60 + 59), isTrue);
      expect(r.isQuietAt(7 * 60), isFalse); // end is exclusive
      expect(r.isQuietAt(12 * 60), isFalse);
      expect(r.isQuietAt(21 * 60 + 59), isFalse);
    });

    test('handles a same-day window', () {
      final r = _reminder(quietStart: '13:00', quietEnd: '15:00');

      expect(r.isQuietAt(12 * 60 + 59), isFalse);
      expect(r.isQuietAt(13 * 60), isTrue);
      expect(r.isQuietAt(14 * 60), isTrue);
      expect(r.isQuietAt(15 * 60), isFalse);
      expect(r.isQuietAt(0), isFalse);
    });

    test('needs both ends of the window', () {
      expect(_reminder(quietStart: '22:00').isQuietAt(23 * 60), isFalse);
      expect(_reminder(quietEnd: '07:00').isQuietAt(3 * 60), isFalse);
    });
  });
}

Reminder _reminder({
  ReminderType type = ReminderType.interval,
  int interval = 90,
  List<String> fixedTimes = const [],
  String? quietStart,
  String? quietEnd,
  List<int> days = const [],
}) => Reminder(
  id: 1,
  title: 'Time to drink water',
  type: type,
  intervalMinutes: interval,
  fixedTimes: fixedTimes,
  quietHoursStart: quietStart,
  quietHoursEnd: quietEnd,
  daysOfWeek: days,
  channel: 'push',
  isActive: true,
);
