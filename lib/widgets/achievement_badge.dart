import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/achievement.dart';
import '../theme.dart';
import 'achievement_glyph.dart';
import 'motion.dart';

/// The round badge on an achievement's rung.
///
/// Two things are said by shape, not colour: the **rings** say how rare it is
/// (none for everyday, one for a milestone, two for a rare one, from the
/// backend's `tier`), and the **fill** says where you are (reached, in
/// progress, ahead).
///
/// A badge that was unlocked since the screen was last opened plays a short
/// animation once: it fills from the grey of a locked one to amber while
/// settling to size, with a single haptic tap. It follows the rest of the
/// app's motion: no bounce, no glow, and none at all when the system asks for
/// reduced motion.
class AchievementBadge extends StatefulWidget {
  final Achievement achievement;

  /// Play the unlock animation (once). Turning true later starts it then.
  final bool animate;

  const AchievementBadge({
    super.key,
    required this.achievement,
    this.animate = false,
  });

  /// Where the unlock animation starts: the badge looks locked, then fills.
  static const Duration delay = Duration(milliseconds: 250);

  @override
  State<AchievementBadge> createState() => _AchievementBadgeState();
}

class _AchievementBadgeState extends State<AchievementBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Timer? _delay;
  bool _played = false;

  /// Not initState: reading the reduced-motion setting depends on MediaQuery,
  /// which may not be read before initState has finished.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animate) _play();
  }

  @override
  void didUpdateWidget(AchievementBadge old) {
    super.didUpdateWidget(old);
    if (widget.animate && !old.animate) _play();
  }

  void _play() {
    if (_played) return;
    _played = true;
    final duration = Motion.of(context, Motion.slow);
    if (duration == Duration.zero) {
      _c.value = 1;
      return;
    }
    _c.duration = duration;
    _c.value = 0;
    _delay = Timer(AchievementBadge.delay, () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _c.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = widget.achievement;
    final done = a.state == 'done';
    final current = a.state == 'current';

    final lockedFill = cs.surfaceContainerHigh;
    final lockedGlyph = cs.onSurface.withValues(alpha: 0.42);

    final ringColor = done
        ? BrandColors.amber500
        : current
        ? BrandColors.amber500.withValues(alpha: 0.6)
        : cs.onSurface.withValues(alpha: 0.18);

    Widget ring(double inset) => Positioned(
      left: -inset,
      top: -inset,
      right: -inset,
      bottom: -inset,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ringColor, width: 1.5),
          ),
        ),
      ),
    );

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (a.tier >= 2) ring(4),
          if (a.tier >= 3) ring(8),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              // Before the animation has run (or when there is none) the
              // badge shows its real state; the controller only matters for a
              // badge that is playing, where t goes 0 -> 1.
              final playing = _played && _c.duration != null;
              final t = playing ? Motion.curve.transform(_c.value) : 1.0;
              final fill = done
                  ? Color.lerp(lockedFill, BrandColors.amber500, t)!
                  : current
                  ? cs.surface
                  : lockedFill;
              final glyph = done
                  ? Color.lerp(lockedGlyph, Colors.white, t)!
                  : current
                  ? BrandColors.amber500
                  : lockedGlyph;

              return Transform.scale(
                scale: playing ? 0.82 + 0.18 * t : 1,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                    border: current
                        ? Border.all(color: BrandColors.amber500, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: AchievementGlyph(
                    achievement: a,
                    size: 20,
                    color: glyph,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
