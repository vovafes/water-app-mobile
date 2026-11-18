import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/api_service.dart';
import '../../models/achievement.dart';
import '../../theme.dart';
import '../../widgets/achievement_glyph.dart';
import '../../widgets/points_label.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => AchievementsScreenState();
}

class AchievementsScreenState extends State<AchievementsScreen> {
  AchievementOverview? _overview;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    if (!mounted) return;
    // Keep what is on screen while refreshing; the tab is reloaded on every
    // visit, and blanking it to a spinner each time made it flicker.
    setState(() => _loading = _overview == null);
    final res = await ApiService.get('/achievements');
    if (!mounted) return;
    final body = res['data'];
    setState(() {
      if (res['success'] == true && body is Map<String, dynamic>) {
        _overview = AchievementOverview.fromJson(body);
      } else if (res['success'] == true && body is List) {
        _overview = AchievementOverview.fromJson({'achievements': body});
      }
      _loading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final overview = _overview;

    return Scaffold(
      appBar: AppBar(title: Text('Achievements'.tr())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (overview != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 14),
                      child: Text(
                        '${overview.unlocked} / ${overview.total} ${'unlocked'.tr()} · '
                        '${overview.points} ${'points'.tr()}',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    if (overview.next != null) ...[
                      _NextGoal(
                        achievement: overview.next!,
                        group: overview.nextGroup,
                        onTap: () => _showDetail(context, overview.next!),
                      ),
                      const SizedBox(height: 16),
                    ],
                    for (final group in overview.groups) ...[
                      _GroupCard(
                        group: group,
                        onTap: (a) => _showDetail(context, a),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

String _count(int n) => NumberFormat.decimalPattern().format(n);

/// "4 / 10" or "4,200 / 10,000 ml", localised.
String _progress(Achievement a) => a.progressLabel(_count, 'ml'.tr());

/// A thin bar with the numbers beside it.
class _ProgressBar extends StatelessWidget {
  final Achievement achievement;
  const _ProgressBar({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              // Never an empty-looking bar once there is some progress.
              value: (achievement.percent / 100).clamp(0.02, 1.0),
              minHeight: 6,
              backgroundColor: cs.onSurface.withValues(alpha: 0.1),
              color: BrandColors.amber500,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _progress(achievement),
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withValues(alpha: 0.65),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// The one thing worth chasing: the rung closest to done.
class _NextGoal extends StatelessWidget {
  final Achievement achievement;
  final String? group;
  final VoidCallback onTap;
  const _NextGoal({
    required this.achievement,
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: BrandColors.amber500,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: AchievementGlyph(
                      achievement: achievement,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group == null
                              ? 'Next goal'.tr()
                              : '${'Next goal'.tr()} · ${context.tr(group!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: BrandColors.amber500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr(achievement.name),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          context.tr(achievement.description),
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ProgressBar(achievement: achievement),
            ],
          ),
        ),
      ),
    );
  }
}

/// One ladder, drawn as a vertical path: the part already climbed is amber.
class _GroupCard extends StatelessWidget {
  final AchievementGroup group;
  final void Function(Achievement) onTap;
  const _GroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr(group.title),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${group.unlockedCount} / ${group.items.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < group.items.length; i++)
              _Rung(
                achievement: group.items[i],
                isLast: i == group.items.length - 1,
                onTap: () => onTap(group.items[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _Rung extends StatelessWidget {
  final Achievement achievement;
  final bool isLast;
  final VoidCallback onTap;
  const _Rung({
    required this.achievement,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = achievement.state == 'done';
    final current = achievement.state == 'current';

    final nodeFill = done
        ? BrandColors.amber500
        : current
        ? cs.surface
        : cs.surfaceContainerHigh;
    final glyphColor = done
        ? Colors.white
        : current
        ? BrandColors.amber500
        : cs.onSurface.withValues(alpha: 0.42);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: nodeFill,
                      shape: BoxShape.circle,
                      border: current
                          ? Border.all(color: BrandColors.amber500, width: 2)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: AchievementGlyph(
                      achievement: achievement,
                      size: 20,
                      color: glyphColor,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: done
                            ? BrandColors.amber500
                            : cs.onSurface.withValues(alpha: 0.15),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 4 : 18, top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            context.tr(achievement.name),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: achievement.state == 'locked'
                                  ? cs.onSurface.withValues(alpha: 0.55)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '+${achievement.points}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: done
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: done
                                ? BrandColors.amber500
                                : cs.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      context.tr(achievement.description),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (current) ...[
                      const SizedBox(height: 8),
                      _ProgressBar(achievement: achievement),
                    ],
                  ],
                ),
              ),
            ),
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
    // SafeArea for the navigation bar, viewInsets for the keyboard — they
    // are different insets and a sheet's last row needs both.
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        // Full width: a bottom sheet is only as wide as its content, so
        // without this it was a narrow card floating in the middle.
        child: SizedBox(
          width: double.infinity,
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
                  color: unlocked
                      ? BrandColors.amber500
                      : cs.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: AchievementGlyph(
                  achievement: achievement,
                  size: 50,
                  color: unlocked ? Colors.white : cs.outline,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(achievement.name),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
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
              if (!unlocked && achievement.target > 1) ...[
                const SizedBox(height: 16),
                _ProgressBar(achievement: achievement),
              ],
              if (achievement.points > 0) ...[
                const SizedBox(height: 8),
                PointsLabel(
                  text: '${achievement.points} ${'points'.tr()}',
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
