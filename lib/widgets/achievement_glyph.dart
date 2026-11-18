import 'package:flutter/material.dart';
import '../models/achievement.dart';

/// The picture for an achievement.
///
/// Built-in achievements arrive with an `icon_key` and are drawn from the
/// Material set, so they look the same on every phone and take the theme's
/// colours. An achievement an admin added has no key; its emoji is shown as
/// typed, and with neither there is a trophy (or a lock, while locked).
///
/// Keys are meanings shared with the website (`AchievementIcons` on the
/// backend); each client maps them to its own icon set.
class AchievementGlyph extends StatelessWidget {
  final Achievement achievement;
  final double size;
  final Color color;

  const AchievementGlyph({
    super.key,
    required this.achievement,
    required this.size,
    required this.color,
  });

  static const _byKey = <String, IconData>{
    'drop': Icons.water_drop_rounded,
    'flame': Icons.local_fire_department_rounded,
    'bolt': Icons.bolt_rounded,
    'trophy': Icons.emoji_events_rounded,
    'badge': Icons.verified_rounded,
    'calendar': Icons.calendar_month_rounded,
    'star': Icons.star_rounded,
    'trend': Icons.trending_up_rounded,
    'scale': Icons.fitness_center_rounded,
    'pencil': Icons.edit_note_rounded,
    'book': Icons.menu_book_rounded,
    'archive': Icons.inventory_2_rounded,
    'stack': Icons.layers_rounded,
    'globe': Icons.public_rounded,
    'swatch': Icons.palette_rounded,
    'map': Icons.map_rounded,
    'puzzle': Icons.extension_rounded,
    'sun': Icons.wb_sunny_rounded,
    'moon': Icons.bedtime_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final glyph = _byKey[achievement.iconKey];
    if (glyph != null) return Icon(glyph, size: size, color: color);

    final emoji = achievement.icon;
    if (emoji != null && emoji.isNotEmpty) {
      return Text(emoji, style: TextStyle(fontSize: size * 0.9));
    }

    return Icon(
      achievement.unlocked
          ? Icons.emoji_events_rounded
          : Icons.lock_outline_rounded,
      size: size,
      color: color,
    );
  }
}
