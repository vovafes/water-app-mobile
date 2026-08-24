import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/api_service.dart';
import '../../models/achievement.dart';
import '../../theme.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => AchievementsScreenState();
}

class AchievementsScreenState extends State<AchievementsScreen> {
  List<Achievement> _achievements = [];
  bool _loading = true;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final res = await ApiService.get('/achievements');
    if (!mounted) return;
    if (res['success'] == true) {
      final body = res['data'];
      List rawList;
      if (body is Map && body['achievements'] is List) {
        rawList = body['achievements'] as List;
      } else if (body is Map && body['data'] is List) {
        rawList = body['data'] as List;
      } else if (body is List) {
        rawList = body;
      } else {
        rawList = const [];
      }
      setState(() {
        _achievements = rawList
            .whereType<Map<String, dynamic>>()
            .map(Achievement.fromJson)
            .toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  List<Achievement> get _visible {
    return switch (_filter) {
      _Filter.all => _achievements,
      _Filter.unlocked => _achievements.where((a) => a.unlocked).toList(),
      _Filter.locked => _achievements.where((a) => !a.unlocked).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unlockedCount = _achievements.where((a) => a.unlocked).length;
    final total = _achievements.length;
    final totalPoints = _achievements
        .where((a) => a.unlocked)
        .fold(0, (sum, a) => sum + a.points);

    return Scaffold(
      appBar: AppBar(title: Text('Achievements'.tr())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _HeroStats(
                    unlocked: unlockedCount,
                    total: total,
                    points: totalPoints,
                  ),
                  const SizedBox(height: 20),
                  _FilterTabs(
                    current: _filter,
                    onChanged: (f) => setState(() => _filter = f),
                    counts: {
                      _Filter.all: total,
                      _Filter.unlocked: unlockedCount,
                      _Filter.locked: total - unlockedCount,
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Column(
                          children: [
                            Text(switch (_filter) {
                              _Filter.unlocked => '🔒',
                              _Filter.locked => '🏆',
                              _Filter.all => '🌟',
                            }, style: const TextStyle(fontSize: 48)),
                            const SizedBox(height: 8),
                            Text(
                              switch (_filter) {
                                _Filter.unlocked =>
                                  'No badges unlocked yet — start logging drinks!'
                                      .tr(),
                                _Filter.locked => 'All badges unlocked!'.tr(),
                                _Filter.all => 'No achievements available'.tr(),
                              },
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.78,
                          ),
                      itemCount: _visible.length,
                      itemBuilder: (context, i) => _BadgeTile(
                        achievement: _visible[i],
                        onTap: () => _showDetail(context, _visible[i]),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  void _showDetail(BuildContext context, Achievement a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _BadgeDetail(achievement: a),
    );
  }
}

enum _Filter { all, unlocked, locked }

class _HeroStats extends StatelessWidget {
  final int unlocked;
  final int total;
  final int points;
  const _HeroStats({
    required this.unlocked,
    required this.total,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? unlocked / total : 0.0;
    final pct = (progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            BrandColors.gradientStartStrong,
            BrandColors.gradientEndStrong,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: BrandColors.sky500.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  color: Colors.white,
                ),
              ),
              const Text('🏆', style: TextStyle(fontSize: 32)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$unlocked / $total ${'badges'.tr()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$pct% ${'complete'.tr()}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                if (points > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '⭐ $points ${'points'.tr()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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

class _FilterTabs extends StatelessWidget {
  final _Filter current;
  final ValueChanged<_Filter> onChanged;
  final Map<_Filter, int> counts;
  const _FilterTabs({
    required this.current,
    required this.onChanged,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    // Each segment gets a third of the width, which German blows past
    // ("Freigeschaltet (0)" wraps onto two lines and desyncs the row
    // heights). Scaling down beats wrapping or ellipsing the count away.
    Widget segment(String label, int count) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text('$label ($count)', maxLines: 1, softWrap: false),
    );

    return SegmentedButton<_Filter>(
      segments: [
        ButtonSegment(
          value: _Filter.all,
          label: segment('All'.tr(), counts[_Filter.all] ?? 0),
        ),
        ButtonSegment(
          value: _Filter.unlocked,
          label: segment('Unlocked'.tr(), counts[_Filter.unlocked] ?? 0),
        ),
        ButtonSegment(
          value: _Filter.locked,
          label: segment('Locked'.tr(), counts[_Filter.locked] ?? 0),
        ),
      ],
      selected: {current},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback onTap;
  const _BadgeTile({required this.achievement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unlocked = achievement.unlocked;

    // Strong amber gradient + white text for unlocked badges so they
    // read well on every theme. Locked tiles use the surface
    // container with subtle outline.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: unlocked
              ? const LinearGradient(
                  colors: [Color(0xFFFF9933), Color(0xFFFF6B6B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: unlocked ? null : cs.surfaceContainer,
          border: Border.all(
            color: unlocked ? Colors.transparent : cs.outline,
            width: 1,
          ),
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF9933).withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unlocked ? Colors.white : cs.surfaceContainerHigh,
                    boxShadow: unlocked
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    achievement.icon ?? (unlocked ? '🏆' : '🔒'),
                    style: TextStyle(
                      fontSize: 26,
                      color: unlocked ? null : cs.outline,
                    ),
                  ),
                ),
                if (unlocked)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: BrandColors.emerald500,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              // Seeded achievement names double as translation keys, same
              // as the web's __($a->name).
              context.tr(achievement.name),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: unlocked
                    ? Colors.white
                    : cs.onSurface.withValues(alpha: 0.75),
              ),
            ),
            if (achievement.points > 0) ...[
              const SizedBox(height: 2),
              Text(
                '⭐ ${achievement.points}',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.3,
                  fontWeight: unlocked ? FontWeight.w600 : FontWeight.normal,
                  color: unlocked
                      ? Colors.white.withValues(alpha: 0.95)
                      : cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeDetail extends StatelessWidget {
  final Achievement achievement;
  const _BadgeDetail({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unlocked = achievement.unlocked;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: unlocked
                  ? const LinearGradient(
                      colors: [Color(0xFFFFC56F), Color(0xFFFF9933)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: unlocked ? null : cs.surfaceContainerHigh,
              shape: BoxShape.circle,
              boxShadow: unlocked
                  ? [
                      BoxShadow(
                        color: BrandColors.amber500.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              achievement.icon ?? (unlocked ? '🏆' : '🔒'),
              style: const TextStyle(fontSize: 48),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(achievement.name),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(achievement.description),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.75),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (unlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: BrandColors.emerald500.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: BrandColors.emerald500.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: BrandColors.emerald500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Unlocked'.tr(),
                    style: const TextStyle(
                      color: BrandColors.emerald500,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Keep going to unlock'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          if (achievement.points > 0) ...[
            const SizedBox(height: 8),
            Text(
              '⭐ ${achievement.points} ${'points'.tr()}',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
