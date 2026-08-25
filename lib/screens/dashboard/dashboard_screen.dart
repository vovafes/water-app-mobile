import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/drink.dart';
import '../../theme.dart';
import '../../widgets/drink_icon.dart';
import '../../widgets/motion.dart';
import '../stats/streak_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat(
            'EEEE, MMM d',
            context.locale.languageCode,
          ).format(DateTime.now()),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => dash.loadDashboard(),
          ),
        ],
      ),
      body: dash.loading && dash.recentLogs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: dash.loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _HeroCard(dash: dash),
                  const SizedBox(height: 16),
                  _DrinkPicker(dash: dash),
                  const SizedBox(height: 16),
                  _RecentLogsCard(dash: dash),
                ],
              ),
            ),
    );
  }
}

/// Sky → cyan gradient card with the progress ring + big numbers +
/// streak chip. Tapping the streak chip opens the detail view.
class _HeroCard extends StatelessWidget {
  final DashboardProvider dash;
  const _HeroCard({required this.dash});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
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
            color: BrandColors.sky500.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -16,
            bottom: -28,
            child: Text(
              '💧',
              style: TextStyle(
                fontSize: 130,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Slimmer progress ring — 84px with stroke 7 reads as
              // proportional to a 22-padding card on phone widths.
              SizedBox(
                width: 84,
                height: 84,
                // One tween drives both the arc and the percentage, so the
                // two cannot drift apart mid-fill. This is the app's whole
                // reward for logging a drink; it earns the slow duration.
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: dash.progress),
                  duration: Motion.of(context, Motion.slow),
                  curve: Motion.curve,
                  builder: (context, progress, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 84,
                        height: 84,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 7,
                          backgroundColor: Colors.white.withValues(alpha: 0.22),
                          color: Colors.white,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'today'.tr(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 10,
                              // Positive tracking rather than a bigger
                              // size: the ring is only 84px across, and
                              // this has to sit under a 19px number.
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // The total counts up; the goal it is measured against
                    // does not move, so only the first half is animated.
                    AnimatedCount(
                      value: dash.consumedMl,
                      duration: Motion.slow,
                      builder: (context, ml) => Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$ml',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                                letterSpacing: -0.4,
                              ),
                            ),
                            TextSpan(
                              text: ' / ${dash.targetMl.toInt()} ${'ml'.tr()}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'of daily goal'.tr(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StreakDetailScreen(),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥'),
                            const SizedBox(width: 6),
                            Text(
                              '${dash.streak} ${'day streak'.tr()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DrinkPicker extends StatelessWidget {
  final DashboardProvider dash;
  const _DrinkPicker({required this.dash});

  void _openVolumeSheet(BuildContext context, Drink drink) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _VolumeSheet(drink: drink, dash: dash),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pick a drink'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (dash.drinks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  // Three across, matching the web's phone breakpoint. Four
                  // was narrow enough that Russian names ("Минеральная")
                  // broke mid-word.
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemCount: dash.drinks.length,
                itemBuilder: (context, i) => _DrinkTile(
                  drink: dash.drinks[i],
                  onTap: () => _openVolumeSheet(context, dash.drinks[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DrinkTile extends StatelessWidget {
  final Drink drink;
  final VoidCallback onTap;
  const _DrinkTile({required this.drink, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final raw = parseHexColor(drink.color) ?? BrandColors.sky500;
    final tone = DrinkColors.from(raw, Theme.of(context).brightness);
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                // tone.rail guarantees a saturated, mid-lightness
                // colour so a white drink (milk) doesn't turn the
                // chip's circle invisible.
                color: tone.rail,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: tone.rail.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: DrinkIcon(slug: drink.slug, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 6),
            // Expanded (rather than a bare Text) so sub-pixel rounding in
            // the grid's tile height can never overflow the column.
            Expanded(
              child: Text(
                // Seeded drink names double as translation keys (same as
                // the web's __($drink->name)); user-created drinks fall
                // through to their own name.
                context.tr(drink.name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumeSheet extends StatefulWidget {
  final Drink drink;
  final DashboardProvider dash;
  const _VolumeSheet({required this.drink, required this.dash});

  @override
  State<_VolumeSheet> createState() => _VolumeSheetState();
}

class _VolumeSheetState extends State<_VolumeSheet> {
  final TextEditingController _custom = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  /// Records the drink and gets out of the way in the same frame.
  ///
  /// Nothing here waits for the network: [DashboardProvider.logDrink] moves
  /// the totals first and reconciles behind the user's back. The
  /// confirmation is the ring filling in behind the closing sheet plus the
  /// tap in the hand — a snackbar saying "250 ml logged" on top of that
  /// would be both redundant and, on a request that later fails, a lie.
  /// Only the failure is worth a message.
  Future<void> _log(int ml) async {
    if (_submitting) return;
    _submitting = true;

    // Both have to be read before the sheet's element is torn down.
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    HapticFeedback.lightImpact();
    Navigator.pop(context);

    final wasComplete = widget.dash.completedGoal;
    // Deliberately not awaited yet: an async function body runs
    // synchronously up to its first `await`, so by the time this returns
    // the optimistic totals are already in. That lets the "goal reached"
    // haptic land with the animation instead of a round-trip later.
    final pending = widget.dash.logDrink(widget.drink.id, ml.toDouble());
    if (!wasComplete && widget.dash.completedGoal) {
      HapticFeedback.mediumImpact();
    }

    if (await pending) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text('Failed to log drink'.tr()),
        backgroundColor: errorColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drink = widget.drink;
    final raw = parseHexColor(drink.color) ?? BrandColors.sky500;
    final tone = DrinkColors.from(raw, Theme.of(context).brightness);
    final volumes = drink.defaultVolumes.isNotEmpty
        ? drink.defaultVolumes
        : const [200, 250, 330, 500];
    final cs = Theme.of(context).colorScheme;

    // viewInsets is the keyboard and nothing else; the navigation bar lives
    // in viewPadding, which SafeArea reads. Without it the Log button sits
    // half under the system bar and half its taps never arrive.
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tone.rail,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: DrinkIcon(
                    slug: drink.slug,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(drink.name),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${drink.hydrationMultiplier.toStringAsFixed(drink.hydrationMultiplier == drink.hydrationMultiplier.roundToDouble() ? 0 : 2)}× ${context.tr('hydration')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Choose amount'.tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6,
              ),
              itemCount: volumes.length,
              itemBuilder: (context, i) {
                final v = volumes[i];
                return InkWell(
                  onTap: _submitting ? null : () => _log(v),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$v ${'ml'.tr()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Custom amount'.tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _custom,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'ml'.tr(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submitting
                      ? null
                      : () {
                          final v = int.tryParse(_custom.text);
                          if (v == null || v < 10 || v > 5000) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Enter 10–5000 ml'.tr())),
                            );
                            return;
                          }
                          _log(v);
                        },
                  child: Text('Log'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Recent logs as a richer list: drink colour as a left rail + circular
/// icon badge + amount as a coloured chip.
class _RecentLogsCard extends StatelessWidget {
  final DashboardProvider dash;
  const _RecentLogsCard({required this.dash});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent logs'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (dash.recentLogs.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${dash.logsCount} · ${dash.consumedMl.toInt()} ${'ml'.tr()}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (dash.recentLogs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No drinks logged yet today. Start with a glass of water!'
                        .tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              )
            else
              ...dash.recentLogs.map((log) {
                final raw = parseHexColor(log.drinkColor) ?? BrandColors.sky500;
                final tone = DrinkColors.from(
                  raw,
                  Theme.of(context).brightness,
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      // Colored left rail — keeps the raw drink colour.
                      Container(
                        width: 4,
                        height: 44,
                        decoration: BoxDecoration(
                          color: tone.rail,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: tone.iconBg,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: _logIcon(log.drinkName, tone.text),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(log.drinkName),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              DateFormat('HH:mm').format(log.consumedAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tone.chipBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${log.volumeMl.toInt()} ${'ml'.tr()}',
                          style: TextStyle(
                            color: tone.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: cs.onSurface.withValues(alpha: 0.4),
                        onPressed: () => dash.deleteDrinkLog(log.id),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  /// We don't have the drink slug on the log payload, so the recent
  /// logs list falls back to a guessed slug based on the localised
  /// name. If the user's locale isn't English the SVG will show the
  /// generic glass — acceptable for a fallback.
  Widget _logIcon(String drinkName, Color color) {
    final slug = _guessSlug(drinkName);
    return DrinkIcon(slug: slug, color: color, size: 22);
  }

  String? _guessSlug(String name) {
    final n = name.toLowerCase();
    if (n.contains('sparkling')) return 'sparkling-water';
    if (n.contains('mineral')) return 'mineral-water';
    if (n.contains('water')) return 'still-water';
    if (n.contains('espresso')) return 'espresso';
    if (n.contains('americano')) return 'americano';
    if (n.contains('latte')) return 'latte';
    if (n.contains('cappuccino') || n.contains('capp')) return 'cappuccino';
    if (n.contains('green tea')) return 'green-tea';
    if (n.contains('black tea')) return 'black-tea';
    if (n.contains('herbal') || n.contains('tea')) return 'herbal-tea';
    if (n.contains('orange juice')) return 'orange-juice';
    if (n.contains('apple juice')) return 'apple-juice';
    if (n.contains('smoothie')) return 'smoothie';
    if (n.contains('cola')) return 'cola';
    if (n.contains('lemon')) return 'lemonade';
    if (n.contains('kefir')) return 'kefir';
    if (n.contains('milk')) return 'milk';
    if (n.contains('isotonic')) return 'isotonic';
    if (n.contains('energy')) return 'energy-drink';
    if (n.contains('beer')) return 'beer';
    if (n.contains('wine')) return 'wine';
    if (n.contains('broth')) return 'broth';
    if (n.contains('coconut')) return 'coconut-water';
    return null;
  }
}
