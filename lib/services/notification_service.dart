import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';

/// Schedules the hydration reminders as *local* notifications.
///
/// The backend stores the schedule but has no dispatcher, so delivery is
/// entirely client-side: every mutation re-materialises the whole set.
class NotificationService {
  static const String channelId = 'water_reminders';

  // The channel name and description are what Android shows in system
  // Settings → Notifications, so they have to follow the app's locale.
  // They are resolved on every use rather than held in a const, because
  // the locale can change after init().
  static String get _channelName => 'Hydration reminders'.tr();
  static String get _channelDescription =>
      'Reminders to drink water throughout the day'.tr();

  /// Notifications per reminder per day. Without quiet hours a 15-minute
  /// interval would otherwise generate 96 slots a day, and Android starts
  /// dropping alarms a few hundred in.
  static const int _maxSlotsPerReminder = 32;

  /// Ceiling across every reminder, well under Android's ~500 alarm budget.
  static const int _maxScheduledTotal = 400;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialised = false;

  static Future<void> init() async {
    if (_initialised) return;

    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      // Unknown/unsupported IANA name — UTC is wrong but harmless enough
      // that it should not stop the app from booting.
      debugPrint('NotificationService: falling back to UTC ($e)');
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    await _ensureChannel();

    _initialised = true;
  }

  /// (Re)declares the channel. Re-creating one with an existing id updates
  /// its name and description in place, which is how a locale switch takes
  /// effect — Android otherwise keeps whatever text the channel was born
  /// with until the app is reinstalled.
  static Future<void> _ensureChannel() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.defaultImportance,
          ),
        );
  }

  /// Asks for the runtime notification permission (Android 13+, iOS).
  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  static Future<bool> hasPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  static Future<void> cancelAll() => _plugin.cancelAll();

  /// Rebuilds every pending notification from [reminders].
  static Future<void> syncAll(List<Reminder> reminders) async {
    await init();
    // init() is a no-op after the first call, so this is the hook that
    // repaints the channel's own text when the user changes language.
    await _ensureChannel();
    await cancelAll();

    if (!await hasPermission()) return;

    var scheduled = 0;
    for (final reminder in reminders) {
      if (!reminder.isActive) continue;
      scheduled += await _schedule(
        reminder,
        budget: _maxScheduledTotal - scheduled,
      );
      if (scheduled >= _maxScheduledTotal) break;
    }
  }

  static Future<int> _schedule(Reminder reminder, {required int budget}) async {
    if (budget <= 0) return 0;

    final slots = slotMinutes(reminder);
    if (slots.isEmpty) return 0;

    // No day filter → one daily-repeating notification per slot. With a
    // filter we need one weekly-repeating notification per (day, slot).
    final weekdays = reminder.everyDay
        ? <int?>[null]
        : reminder.daysOfWeek.cast<int?>();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    var count = 0;
    var index = 0;
    for (final weekday in weekdays) {
      for (final slot in slots) {
        if (count >= budget) return count;
        await _plugin.zonedSchedule(
          id: reminder.id * 1000 + index,
          title: reminder.title,
          // Baked in at schedule time — a locale switch only takes effect
          // after the next sync.
          body: 'Time for a glass of water'.tr(),
          scheduledDate: nextInstance(slot, weekday: weekday),
          notificationDetails: details,
          // Inexact keeps us clear of SCHEDULE_EXACT_ALARM, which Play
          // restricts to alarm/calendar apps. A drink nudge can slide.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: weekday == null
              ? DateTimeComponents.time
              : DateTimeComponents.dayOfWeekAndTime,
          payload: 'reminder:${reminder.id}',
        );
        index++;
        count++;
      }
    }
    return count;
  }

  /// Minutes-since-midnight at which [reminder] should fire on an active day.
  ///
  /// Interval reminders start at the end of the quiet window (i.e. wake-up)
  /// and step forward until they run back into it, so the last slot of the
  /// day sits just before quiet hours begin.
  @visibleForTesting
  static List<int> slotMinutes(Reminder reminder) {
    if (reminder.type == ReminderType.fixed) {
      final times =
          reminder.fixedTimes
              .map(minutesOfDay)
              .whereType<int>()
              .toSet()
              .toList()
            ..sort();
      return times.take(_maxSlotsPerReminder).toList();
    }

    const dayMinutes = 24 * 60;
    final step = reminder.intervalMinutes.clamp(
      Reminder.minIntervalMinutes,
      Reminder.maxIntervalMinutes,
    );
    final start = reminder.quietEndMinutes ?? 0;

    final slots = <int>[];
    for (var elapsed = 0; elapsed < dayMinutes; elapsed += step) {
      final minute = (start + elapsed) % dayMinutes;
      if (reminder.isQuietAt(minute)) break;
      slots.add(minute);
      if (slots.length >= _maxSlotsPerReminder) break;
    }
    slots.sort();
    return slots;
  }

  /// Next future occurrence of [minuteOfDay], optionally constrained to an
  /// ISO [weekday] (1 = Monday).
  @visibleForTesting
  static tz.TZDateTime nextInstance(int minuteOfDay, {int? weekday}) {
    final now = tz.TZDateTime.now(tz.local);
    for (var offset = 0; offset < 14; offset++) {
      final day = now.add(Duration(days: offset));
      final candidate = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        minuteOfDay ~/ 60,
        minuteOfDay % 60,
      );
      if (candidate.isAfter(now) &&
          (weekday == null || candidate.weekday == weekday)) {
        return candidate;
      }
    }
    // Unreachable for any valid weekday, but zonedSchedule needs a date.
    final tomorrow = now.add(const Duration(days: 1));
    return tz.TZDateTime(
      tz.local,
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      minuteOfDay ~/ 60,
      minuteOfDay % 60,
    );
  }
}
