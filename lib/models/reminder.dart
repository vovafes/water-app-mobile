/// Mirrors the `reminders` table exposed by
/// `Api\V1\ReminderController` — see its `validateReminder()` for the
/// authoritative constraints (interval 15..720, times as `H:i`, etc.).
enum ReminderType {
  interval,
  fixed,

  /// Stored by the backend but never produced by this client; the planner
  /// treats it exactly like [interval], so we do too.
  smart;

  static ReminderType fromString(String? raw) => switch (raw) {
    'fixed' => ReminderType.fixed,
    'smart' => ReminderType.smart,
    _ => ReminderType.interval,
  };

  String get wire => name;
}

class Reminder {
  static const int minIntervalMinutes = 15;
  static const int maxIntervalMinutes = 720;

  final int id;
  final String title;
  final ReminderType type;
  final int intervalMinutes;

  /// `HH:mm` strings, sorted ascending.
  final List<String> fixedTimes;
  final String? quietHoursStart;
  final String? quietHoursEnd;

  /// ISO weekdays, 1 = Monday … 7 = Sunday, matching [DateTime.weekday].
  /// Empty means "every day".
  final List<int> daysOfWeek;

  final String channel;
  final bool isActive;

  const Reminder({
    required this.id,
    required this.title,
    required this.type,
    required this.intervalMinutes,
    required this.fixedTimes,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    required this.daysOfWeek,
    required this.channel,
    required this.isActive,
  });

  Reminder copyWith({
    String? title,
    ReminderType? type,
    int? intervalMinutes,
    List<String>? fixedTimes,
    String? quietHoursStart,
    String? quietHoursEnd,
    List<int>? daysOfWeek,
    bool? isActive,
    bool clearQuietHours = false,
  }) => Reminder(
    id: id,
    title: title ?? this.title,
    type: type ?? this.type,
    intervalMinutes: intervalMinutes ?? this.intervalMinutes,
    fixedTimes: fixedTimes ?? this.fixedTimes,
    quietHoursStart: clearQuietHours
        ? null
        : (quietHoursStart ?? this.quietHoursStart),
    quietHoursEnd: clearQuietHours
        ? null
        : (quietHoursEnd ?? this.quietHoursEnd),
    daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    channel: channel,
    isActive: isActive ?? this.isActive,
  );

  int? get quietStartMinutes => minutesOfDay(quietHoursStart);
  int? get quietEndMinutes => minutesOfDay(quietHoursEnd);

  bool get hasQuietHours =>
      quietStartMinutes != null && quietEndMinutes != null;

  bool get everyDay => daysOfWeek.isEmpty || daysOfWeek.length >= 7;

  /// Mirrors `ReminderPlannerService::isQuietHour()`, including its
  /// wrap-past-midnight branch.
  bool isQuietAt(int minuteOfDay) {
    final start = quietStartMinutes;
    final end = quietEndMinutes;
    if (start == null || end == null) return false;
    if (start <= end) return minuteOfDay >= start && minuteOfDay < end;
    return minuteOfDay >= start || minuteOfDay < end;
  }

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
    id: _readInt(json['id']) ?? 0,
    title: (json['title'] ?? 'Time to drink water').toString(),
    type: ReminderType.fromString(json['type']?.toString()),
    intervalMinutes: (_readInt(json['interval_minutes']) ?? 90).clamp(
      minIntervalMinutes,
      maxIntervalMinutes,
    ),
    fixedTimes: _readTimes(json['fixed_times']),
    quietHoursStart: _readTime(json['quiet_hours_start']),
    quietHoursEnd: _readTime(json['quiet_hours_end']),
    daysOfWeek: _readDays(json['days_of_week']),
    channel: (json['channel'] ?? 'push').toString(),
    isActive: json['is_active'] != false && json['is_active'] != 0,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'type': type.wire,
    'interval_minutes': intervalMinutes,
    'fixed_times': fixedTimes,
    'quiet_hours_start': quietHoursStart,
    'quiet_hours_end': quietHoursEnd,
    'days_of_week': daysOfWeek,
    'channel': channel,
    'is_active': isActive,
  };
}

/// `HH:mm` → minutes since midnight, or null when unparseable.
int? minutesOfDay(String? hm) {
  if (hm == null) return null;
  final parts = hm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

String formatHm(int minuteOfDay) {
  final m = minuteOfDay % (24 * 60);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

/// The `time` columns come back as `HH:mm` thanks to the `datetime:H:i`
/// cast, but tolerate `HH:mm:ss` and full ISO timestamps too.
String? _readTime(dynamic v) {
  if (v == null) return null;
  final raw = v.toString();
  if (raw.isEmpty) return null;
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw);
  if (match == null) return null;
  final h = int.parse(match.group(1)!);
  final m = int.parse(match.group(2)!);
  if (h > 23 || m > 59) return null;
  return formatHm(h * 60 + m);
}

List<String> _readTimes(dynamic v) {
  if (v is! List) return const [];
  final times = v.map(_readTime).whereType<String>().toSet().toList()..sort();
  return times;
}

List<int> _readDays(dynamic v) {
  if (v is! List) return const [];
  final days =
      v
          .map(_readInt)
          .whereType<int>()
          .where((d) => d >= 1 && d <= 7)
          .toSet()
          .toList()
        ..sort();
  return days;
}

int? _readInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}
