import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/entitlement.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/purchase_service.dart';
import '../../theme.dart';
import '../../widgets/legal_footer.dart';

/// Which headline the paywall opens with.
///
/// The three variants are the A/B set from MONETIZATION.md §7. They test
/// different triggers, not different wordings of the same one, so the
/// winner tells you something. Judge them on **payment at day four**, not
/// on trial starts: [sunkCost] reliably wins the start and loses the money,
/// because pressure brings in people who were never going to pay.
enum PaywallAngle {
  /// Physiology. Sells the thing competitors do not have. Default.
  physiology,

  /// Effort already spent. Only meaningful straight after onboarding — in a
  /// contextual paywall there is no effort to point at.
  sunkCost,

  /// The month-from-now outcome. Travels better to en/uk and to the
  /// "history past 7 days" prompt.
  outcome,
}

/// The post-onboarding paywall.
///
/// Structure follows MONETIZATION.md §6 top to bottom. Two parts of it are
/// App Review requirements rather than taste, and should not be tuned away:
/// the close control is visible from the first frame (Guideline 3.1.2), and
/// Restore is always reachable.
class PaywallScreen extends StatefulWidget {
  /// The number onboarding just produced, in ml. Shown first, before any
  /// branding — the screen continues onboarding rather than interrupting
  /// it.
  ///
  /// When null the screen reads it from [DashboardProvider] instead, and
  /// only once that provider has really loaded. Showing the placeholder
  /// 2000 would open the pitch with a fabricated personal number, which is
  /// exactly the claim the rest of the screen rests on.
  final double? targetMl;

  final PaywallAngle angle;

  /// Named so it shows up in analytics: `onboarding`, `drinks`,
  /// `reminders`, `history`, `profile`.
  final String source;

  final PurchaseService purchases;

  const PaywallScreen({
    super.key,
    this.targetMl,
    this.angle = PaywallAngle.physiology,
    required this.source,
    this.purchases = const UnconfiguredPurchaseService(),
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  List<PremiumPlan> _plans = const [];
  PremiumPlan? _selected;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plans = await widget.purchases.plans();
    if (!mounted) return;
    setState(() {
      _plans = plans;
      // Annual is preselected, always. It is the plan the screen exists to
      // sell; the monthly one is there to make it look like the deal.
      _selected = plans.isEmpty
          ? null
          : plans.firstWhere(
              (p) => p.tier == PremiumTier.annual,
              orElse: () => plans.first,
            );
      _loading = false;
    });
  }

  Future<void> _buy() async {
    final plan = _selected;
    if (plan == null) return;
    setState(() => _busy = true);
    final result = await widget.purchases.purchase(plan.productId);
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case PurchaseResult.success:
        // The store said yes; the backend still has the final word. Pulling
        // /auth/me is what turns the purchase into an entitlement.
        await context.read<AuthProvider>().refreshUser();
        if (mounted) Navigator.of(context).pop(true);
      case PurchaseResult.cancelled:
        // Backing out of the store sheet is not an error. Say nothing.
        break;
      case PurchaseResult.unavailable:
        _toast('Purchases are not available yet'.tr());
      case PurchaseResult.failed:
        _toast('The purchase did not go through'.tr());
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    final restored = await widget.purchases.restore();
    if (!mounted) return;
    if (restored) await context.read<AuthProvider>().refreshUser();
    if (!mounted) return;
    setState(() => _busy = false);
    if (restored) {
      Navigator.of(context).pop(true);
    } else {
      _toast('Nothing to restore on this account'.tr());
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _selected;
    final dashboard = context.watch<DashboardProvider>();
    final target =
        widget.targetMl ?? (dashboard.hasLoaded ? dashboard.targetMl : null);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onClose: () => Navigator.of(context).pop(false),
              onRestore: _restore,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        if (target != null) ...[
                          _TargetEcho(targetMl: target),
                          const SizedBox(height: 20),
                        ],
                        _Headline(angle: widget.angle),
                        const SizedBox(height: 22),
                        const _Benefits(),
                        const SizedBox(height: 22),
                        if (plan?.trial != null) ...[
                          _TrialTimeline(trial: plan!.trial!),
                          const SizedBox(height: 22),
                        ],
                        for (final p in _plans) ...[
                          _PlanRow(
                            plan: p,
                            selected: identical(p, _selected),
                            onTap: () => setState(() => _selected = p),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
            ),
            if (!_loading)
              _CallToAction(
                plan: plan,
                busy: _busy,
                onBuy: _buy,
                onDecline: () => Navigator.of(context).pop(false),
              ),
          ],
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
    );
  }
}

/// Close on the left, Restore on the right. Both live from the first frame:
/// a close control that fades in after a delay, or is too small to hit, is
/// what Guideline 3.1.2 rejections are made of.
class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onRestore;

  const _TopBar({required this.onClose, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            tooltip: 'Close'.tr(),
            iconSize: 26,
          ),
          TextButton(onPressed: onRestore, child: Text('Restore'.tr())),
        ],
      ),
    );
  }
}

/// Step 1 — the number onboarding just produced.
class _TargetEcho extends StatelessWidget {
  final double targetMl;

  const _TargetEcho({required this.targetMl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [BrandColors.gradientStart, BrandColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Text(
            NumberFormat.decimalPattern(
              context.locale.languageCode,
            ).format(targetMl.round()),
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ml — your daily goal'.tr(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: dark ? Colors.white : Colors.white.withValues(alpha: 0.92),
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 2 — one idea, two sentences.
class _Headline extends StatelessWidget {
  final PaywallAngle angle;

  const _Headline({required this.angle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (head, sub) = switch (angle) {
      PaywallAngle.physiology => (
        'This number changes every day'.tr(),
        'Heat, a workout, a short night — your goal adjusts to what is actually going on. The free plan shows the average.'
            .tr(),
      ),
      PaywallAngle.sunkCost => (
        'Eight answers. One number. Don\'t stop here'.tr(),
        'You just told the app about your weight, your climate and your sleep. Premium turns that into a goal that lives, instead of one that sits there.'
            .tr(),
      ),
      PaywallAngle.outcome => (
        'In 30 days you\'ll know what you actually drink'.tr(),
        'Not a feeling — a record. Every day, every drink, every slip. The free plan remembers a week.'
            .tr(),
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          head,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          sub,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// Step 3 — three, not ten. A long list reads as justifying the price, and
/// each extra row is one more thing to disbelieve.
class _Benefits extends StatelessWidget {
  const _Benefits();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Built here rather than as a const list so each string carries .tr()
    // on the literal itself, which is what keeps them out of English-only
    // builds — and what the i18n test checks for.
    final rows = <(IconData, String)>[
      (Icons.thermostat, 'Your goal recalculated for weather and effort'.tr()),
      (
        Icons.local_cafe_outlined,
        'Every drink, at its real hydration coefficient'.tr(),
      ),
      (
        Icons.timeline_outlined,
        'Full history and streaks, with no cut-off'.tr(),
      ),
    ];
    return Column(
      children: [
        for (final (icon, text) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: BrandColors.sky500),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Step 4 — what happens on each of the three days.
///
/// This is the highest-leverage block on the screen. "I'll forget to
/// cancel" is the single biggest reason people decline a trial, and saying
/// the schedule out loud removes it. The day-two promise is load-bearing:
/// the reminder has to actually be sent, or this becomes the reason for the
/// one-star review rather than the cure for it.
class _TrialTimeline extends StatelessWidget {
  final Duration trial;

  const _TrialTimeline({required this.trial});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = trial.inDays;
    final cells = [
      ('Today'.tr(), 'Full access'.tr()),
      ('Day {n}'.tr(namedArgs: {'n': '${days - 1}'}), 'We remind you'.tr()),
      ('Day {n}'.tr(namedArgs: {'n': '$days'}), 'Billing starts'.tr()),
    ];

    return Row(
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Text(
                    cells[i].$1.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cells[i].$2,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Step 5 — annual first and preselected, with the per-month figure spelled
/// out. People compare monthly numbers even when buying a year.
class _PlanRow extends StatelessWidget {
  final PremiumPlan plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanRow({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (plan.tier) {
      PremiumTier.annual => 'Yearly'.tr(),
      PremiumTier.monthly => 'Monthly'.tr(),
      PremiumTier.lifetime => 'Lifetime'.tr(),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? BrandColors.sky500.withValues(alpha: 0.08)
              : theme.colorScheme.surface,
          border: Border.all(
            color: selected
                ? BrandColors.sky500
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (plan.savingBadge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: BrandColors.sky500,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        plan.savingBadge!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.perMonth != null
                      ? '${plan.perMonth}/${'mo'.tr()}'
                      : plan.price,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (plan.perMonth != null)
                  Text(
                    plan.price,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Steps 6–8 — button, real price, and a decline that isn't a guilt trip.
class _CallToAction extends StatelessWidget {
  final PremiumPlan? plan;
  final bool busy;
  final VoidCallback onBuy;
  final VoidCallback onDecline;

  const _CallToAction({
    required this.plan,
    required this.busy,
    required this.onBuy,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = plan;

    // The word "subscribe" never appears on the primary button of a trial
    // plan. "Buy" appears exactly once, on Lifetime, because that is what
    // it is.
    final cta = switch (p?.tier) {
      null => 'Continue'.tr(),
      PremiumTier.annual when p!.trial != null => 'Try {n} days free'.tr(
        namedArgs: {'n': '${p.trial!.inDays}'},
      ),
      PremiumTier.annual => 'Subscribe for {price}/yr'.tr(
        namedArgs: {'price': p!.price},
      ),
      PremiumTier.monthly => 'Subscribe for {price}/mo'.tr(
        namedArgs: {'price': p!.price},
      ),
      PremiumTier.lifetime => 'Buy for good — {price}'.tr(
        namedArgs: {'price': p!.price},
      ),
    };

    // Required by both stores, and the same size as the rest of the fine
    // print rather than hidden at 8pt.
    final fine = switch (p?.tier) {
      PremiumTier.annual when p!.trial != null =>
        'Then {price}/yr · Cancel anytime'.tr(namedArgs: {'price': p.price}),
      PremiumTier.lifetime => 'One payment · Yours for good'.tr(),
      _ => 'Cancel anytime'.tr(),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onBuy,
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(cta),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fine,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: busy ? null : onDecline,
            // Not "No thanks" and not "Maybe later" — both lean on guilt,
            // and both read as a dark pattern to a reviewer.
            child: Text('Continue with the free plan'.tr()),
          ),
          // Required on the purchase screen itself by Apple 3.1.2 and Play's
          // subscription policy. Lifetime renews nothing, so it is shown
          // the links without the renewal sentence.
          LegalFooter(renewing: p?.tier != PremiumTier.lifetime),
        ],
      ),
    );
  }
}
