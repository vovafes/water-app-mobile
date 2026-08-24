import 'package:flutter/material.dart';

/// The app's motion values, in one place.
///
/// Three durations and one curve, because a house style that offers more
/// than that stops being a style. Anything that animates picks from here
/// rather than inventing a number at the call site.
class Motion {
  const Motion._();

  /// Press feedback and other changes that must not read as travel.
  static const Duration fast = Duration(milliseconds: 120);

  /// The default for a value changing on screen.
  static const Duration normal = Duration(milliseconds: 300);

  /// Reserved for the one thing worth watching: the ring and the daily
  /// total filling in after a drink is logged.
  static const Duration slow = Duration(milliseconds: 650);

  /// Critically damped — reaches the target and stops, no overshoot.
  ///
  /// Bounce belongs to motion the user's own gesture threw. Nothing in this
  /// app is thrown: every animation here is a number changing because a
  /// button was tapped, and overshoot on that reads as a glitch rather than
  /// as physics.
  static const Curve curve = Curves.easeOutCubic;

  /// [d], or zero when the platform asks for reduced motion.
  ///
  /// Reduced motion is not "no feedback" — the number still changes and the
  /// ring still fills, they simply arrive without travelling. Routing every
  /// duration through here is what keeps that promise app-wide instead of
  /// per-widget.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

/// A number that counts to its new value instead of cutting to it.
///
/// Takes a [builder] rather than a style so callers can put the animated
/// number inside whatever text they need — "1750 / 2640 ml" is one line of
/// mixed styles, not a bare number.
class AnimatedCount extends StatelessWidget {
  final num value;
  final Duration duration;
  final Widget Function(BuildContext context, int value) builder;

  const AnimatedCount({
    super.key,
    required this.value,
    required this.builder,
    this.duration = Motion.normal,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // No `begin`: TweenAnimationBuilder fills it with the value currently
      // on screen, which is what makes an interrupted count continue from
      // where it visibly is rather than jump back to the old total.
      tween: Tween<double>(end: value.toDouble()),
      duration: Motion.of(context, duration),
      curve: Motion.curve,
      builder: (context, v, _) => builder(context, v.round()),
    );
  }
}
