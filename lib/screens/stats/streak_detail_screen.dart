import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

/// One day's progress, mirrored from /api/v1/statistics/daily.
class _DayStat {
  final DateTime date;
  final int targetMl;
  final int consumedMl;
  final int hydrationMl;
  final int hydrationPercent;
  final bool completedGoal;

  const _DayStat({
    required this.date,
    required this.targetMl,
    required this.consumedMl,
    required this.hydrationMl,
    required this.hydrationPercent,
    required this.completedGoal,
  });

  bool get hasLogs => consumedMl > 0;
}

/// Duolingo-ish streak view. Calendar with active days highlighted +
/// goal-hit days with a flame badge. Selecting a day shows that day's
/// summary below.
class StreakDetailScreen extends StatefulWidget {
  const StreakDetailScreen({super.key});

  @override
  State<StreakDetailScreen> createState() => _StreakDetailScreenState();
}

class _StreakDetailScreenState extends State<StreakDetailScreen> {
  final Map<DateTime, _DayStat> _byDay = {};
  bool _loading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  int _activeDays = 0;
  int _completedDays = 0;
  int _streak = 0;
  int _bestStreak = 0;

  @override
  void initState() {
    super.initState();
    _selectedDay = _stripTime(_focusedDay);
    _load();
  }

  static DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/statistics/daily?days=90');
    if (!mounted) return;
    if (res['success'] == true && res['data'] is Map) {
      final body = res['data'] as Map;
      final list = body['data'];
      if (list is List) {
        _byDay.clear();
        for (final row in list) {
          if (row is! Map) continue;
          final dateStr = row['date']?.toString();
          if (dateStr == null) continue;
          final d = DateTime.tryParse(dateStr);
          if (d == null) continue;
          _byDay[_stripTime(d)] = _DayStat(
            date: d,
            targetMl: _toInt(row['target_ml']),
            consumedMl: _toInt(row['consumed_ml']),
            hydrationMl: _toInt(row['hydration_ml']),
            hydrationPercent: _toInt(row['hydration_percent']),
            completedGoal: row['completed_goal'] == true,
          );
        }
        _computeStreaks();
      }
    }
    setState(() => _loading = false);
  }

  void _computeStreaks() {
    final today = _stripTime(DateTime.now());
    int active = 0;
    int completed = 0;
    int currentStreak = 0;
    int best = 0;
    int run = 0;

    final dates = _byDay.keys.toList()..sort();
    for (final d in dates) {
      final s = _byDay[d]!;
      if (s.hasLogs) active++;
      if (s.completedGoal) completed++;
      if (s.completedGoal) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }

    // Current streak counts back from today as long as each day hit
    // the goal. Today itself counts if either the goal is already met
    // or it's still in progress (we don't break the streak mid-day).
    for (int back = 0; back < 365; back++) {
      final d = today.subtract(Duration(days: back));
      final s = _byDay[d];
      if (s == null) break;
      if (s.completedGoal) {
        currentStreak++;
      } else if (back == 0) {
        // Don't break the streak before the day ends.
        continue;
      } else {
        break;
      }
    }

    _activeDays = active;
    _completedDays = completed;
    _streak = currentStreak;
    _bestStreak = best;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Streak'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _StreakHero(
                    streak: _streak,
                    bestStreak: _bestStreak,
                    activeDays: _activeDays,
                    completedDays: _completedDays,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: TableCalendar<_DayStat>(
                        firstDay: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDay: DateTime.now().add(const Duration(days: 30)),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                        onDaySelected: (selected, focused) {
                          setState(() {
                            _selectedDay = _stripTime(selected);
                            _focusedDay = focused;
                          });
                        },
                        onPageChanged: (focused) => _focusedDay = focused,
                        eventLoader: (day) {
                          final s = _byDay[_stripTime(day)];
                          return s == null ? [] : [s];
                        },
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Month',
                        },
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          leftChevronIcon: Icon(
                            Icons.chevron_left,
                            color: cs.onSurface,
                          ),
                          rightChevronIcon: Icon(
                            Icons.chevron_right,
                            color: cs.onSurface,
                          ),
                        ),
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: false,
                          todayDecoration: BoxDecoration(
                            color: cs.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          todayTextStyle: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: TextStyle(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          markersAlignment: Alignment.bottomCenter,
                        ),
                        calendarBuilders: CalendarBuilders<_DayStat>(
                          markerBuilder: (context, day, events) {
                            if (events.isEmpty) return null;
                            final s = events.first;
                            if (s.completedGoal) {
                              return Positioned(
                                bottom: 1,
                                right: 1,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: BrandColors.amber500,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: cs.surface,
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '🔥',
                                    style: TextStyle(fontSize: 9),
                                  ),
                                ),
                              );
                            }
                            if (s.hasLogs) {
                              return Positioned(
                                bottom: 2,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: BrandColors.sky500,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DayDetail(
                    stat: _byDay[_stripTime(_selectedDay)],
                    date: _selectedDay,
                  ),
                  const SizedBox(height: 16),
                  _Legend(),
                ],
              ),
            ),
    );
  }
}

class _StreakHero extends StatelessWidget {
  final int streak;
  final int bestStreak;
  final int activeDays;
  final int completedDays;
  const _StreakHero({
    required this.streak,
    required this.bestStreak,
    required this.activeDays,
    required this.completedDays,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8A00), Color(0xFFFF4D6D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8A00).withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 60)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$streak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        height: 1,
                      ),
                    ),
                    Text(
                      'day streak'.tr(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Best'.tr(),
                  value: '$bestStreak',
                  suffix: 'days'.tr(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Active'.tr(),
                  value: '$activeDays',
                  suffix: 'days'.tr(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Goals hit'.tr(),
                  value: '$completedDays',
                  suffix: 'days'.tr(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: ' $suffix',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  final _DayStat? stat;
  final DateTime date;
  const _DayDetail({required this.stat, required this.date});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat(
                    'EEEE, MMM d',
                    context.locale.languageCode,
                  ).format(date),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (stat?.completedGoal == true)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: BrandColors.amber500.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          'Goal hit'.tr(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (stat == null || !stat!.hasLogs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No drinks logged this day.'.tr(),
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _StatBlock(
                      label: 'Consumed'.tr(),
                      value: '${stat!.consumedMl}',
                      suffix: 'ml',
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatBlock(
                      label: 'Hydration'.tr(),
                      value: '${stat!.hydrationMl}',
                      suffix: 'ml',
                      color: BrandColors.cyan500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: stat!.targetMl > 0
                      ? (stat!.consumedMl / stat!.targetMl).clamp(0.0, 1.0)
                      : 0,
                  minHeight: 10,
                  backgroundColor: cs.surfaceContainer,
                  color: stat!.completedGoal
                      ? BrandColors.amber500
                      : cs.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr(
                  'Target: {ml} ml · {percent}% hydrated',
                  namedArgs: {
                    'ml': '${stat!.targetMl}',
                    'percent': '${stat!.hydrationPercent}',
                  },
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final Color color;
  const _StatBlock({
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: ' $suffix',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _legendItem(
            cs,
            Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: BrandColors.amber500,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('🔥', style: TextStyle(fontSize: 9)),
            ),
            'Goal hit'.tr(),
          ),
          _legendItem(
            cs,
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: BrandColors.sky500,
                shape: BoxShape.circle,
              ),
            ),
            'Logged drinks'.tr(),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(ColorScheme cs, Widget marker, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 18, height: 18, child: Center(child: marker)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
