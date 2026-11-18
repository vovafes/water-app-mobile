import 'package:flutter/material.dart';
import '../theme.dart';

/// "★ 120 points" as an icon next to text.
///
/// This was a star emoji in the string, which each platform draws in its own
/// style (Apple's, Google's) and which ignores the text colour, so it looked
/// different on every phone and in dark mode. The icon is the same everywhere.
class PointsLabel extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final Color iconColor;

  const PointsLabel({
    super.key,
    required this.text,
    this.fontSize = 12,
    this.fontWeight,
    this.color,
    this.iconColor = BrandColors.amber500,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: fontSize + 3, color: iconColor),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
          ),
        ),
      ],
    );
  }
}
