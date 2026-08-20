import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:water_app_mobile/models/reminder.dart';
import 'package:water_app_mobile/services/notification_service.dart';

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    // UTC has no DST transitions, so a wall-clock time always exists and
    // nextInstance() can be asserted exactly.
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  group('slotMinutes — fixed times', () {
    test('parses, dedupes and sorts', () {
      final slots = NotificationService.slotMinutes(
        _reminder(
          type: ReminderType.fixed,
          fixedTimes: ['19:15', '08:00', '08:00', '13:30'],
        ),
      );
      expect(slots, [480, 810, 1155]);
    });

    test('ignores quiet hours — an explicit time is an explicit request', () {
      final slots = NotificationService.slotMinutes(
        _reminder(
          type: ReminderType.fixed,
          fixedTimes: ['23:00'],
          quietStart: '22:00',
          quietEnd: '07:00',
        ),
      );
      expect(slots, [1380]);
    });

    test('is empty when no times are set', () {
      expect(
        NotificationService.slotMinutes(_reminder(type: ReminderType.fixed)),
        isEmpty,
      );
    });
  });

  group('slotMinutes — intervals', () {
    test('starts at midnight and fills the day without quiet hours', () {
      final slots = NotificationService.slotMinutes(_reminder(interval: 90));
      expect(slots.first, 0);
      expect(slots.length, 16); // 1440 / 90
      expect(slots.last, 1350);
    });

    test('starts at wake-up and stops when it runs back into quiet hours', () {
      final slots = NotificationService.slotMinutes(
        _reminder(interval: 180, quietStart: '22:00', quietEnd: '07:00'),
      );
      // 07:00, 10:00, 13:00, 16:00, 19:00 — the 22:00 step lands in the
      // quiet window and ends the day.
      expect(slots.map(formatHm).toList(), [
        '07:00',
        '10:00',
        '13:00',
        '16:00',
        '19:00',
      ]);
    });

    test('still yields the wake-up slot when quiet hours swallow the day', () {
      final slots = NotificationService.slotMinutes(
        _reminder(interval: 90, quietStart: '08:00', quietEnd: '07:00'),
      );
      expect(slots.map(formatHm).toList(), ['07:00']);
    });

    test('caps the per-reminder slot count', () {
      // 15 minutes with no quiet window would otherwise be 96 alarms a day.
      final slots = NotificationService.slotMinutes(_reminder(interval: 15));
      expect(slots.length, 32);
    });

    test('clamps an out-of-range interval instead of looping forever', () {
      final slots = NotificationService.slotMinutes(_reminder(interval: 0));
      expect(slots.length, 32);
    });

    test('treats smart like interval', () {
      expect(
        NotificationService.slotMinutes(
          _reminder(type: ReminderType.smart, interval: 720),
        ),
        [0, 720],
      );
    });

    test('returns a sorted list even when the window wraps', () {
      final slots = NotificationService.slotMinutes(
        _reminder(interval: 120, quietStart: '02:00', quietEnd: '23:00'),
      );
      final sorted = [...slots]..sort();
      expect(slots, sorted);
      // Steps 23:00 → 01:00 → 03:00, and 03:00 is inside the window.
      expect(slots.map(formatHm).toList(), ['01:00', '23:00']);
    });
  });

  group('nextInstance', () {
    test('is always in the future and keeps the wall-clock time', () {
      for (final minute in [0, 7 * 60, 13 * 60 + 30, 23 * 60 + 59]) {
        final next = NotificationService.nextInstance(minute);
        expect(next.isAfter(tz.TZDateTime.now(tz.local)), isTrue);
        expect(next.hour * 60 + next.minute, minute);
        expect(
          next.difference(tz.TZDateTime.now(tz.local)).inHours,
          lessThan(24),
        );
      }
    });

    test('lands on the requested ISO weekday within a week', () {
      for (var weekday = 1; weekday <= 7; weekday++) {
        final next = NotificationService.nextInstance(9 * 60, weekday: weekday);
        expect(next.weekday, weekday);
        expect(next.hour, 9);
        expect(next.isAfter(tz.TZDateTime.now(tz.local)), isTrue);
        expect(
          next.difference(tz.TZDateTime.now(tz.local)).inDays,
          lessThan(8),
        );
      }
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
