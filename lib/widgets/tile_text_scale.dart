import 'package:flutter/material.dart';

/// How far a fixed-size grid tile can honour the system font size.
///
/// Phones with "Large text" on (1.5x and up is common) clipped drink names
/// mid-word and overflowed the achievement tiles, because the tiles have a
/// fixed height. Text inside a tile is capped here and the tile grows by the
/// same factor, so large text still gets bigger, just not past what fits.
const double kTileMaxTextScale = 1.15;

/// The text scale a tile will actually use, between 1 and [kTileMaxTextScale].
double tileTextScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1).clamp(1.0, kTileMaxTextScale);

/// Caps the text scale of a tile's content. Pair it with a grid extent of
/// `base * tileTextScale(context)`.
class TileTextScale extends StatelessWidget {
  final Widget child;
  const TileTextScale({super.key, required this.child});

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    minScaleFactor: 1.0,
    maxScaleFactor: kTileMaxTextScale,
    child: child,
  );
}
