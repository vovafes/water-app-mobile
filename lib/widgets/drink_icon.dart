import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a drink-specific vector icon by slug. The 22 paths below are
/// the Dart counterpart of the web app's
/// `resources/views/components/icons/drink-icon.blade.php` Blade
/// component so both clients show the same shape for the same drink.
///
/// `color` is applied wherever the SVG uses `currentColor`. The web
/// passes the drink's hex colour here too.
class DrinkIcon extends StatelessWidget {
  final String? slug;
  final double size;
  final Color color;

  const DrinkIcon({
    super.key,
    required this.slug,
    required this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final body = _bodyFor(slug);
    final hex =
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    final svg =
        '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="$size" height="$size" color="$hex">
$body
</svg>
''';
    return SvgPicture.string(svg, width: size, height: size);
  }

  static String _bodyFor(String? slug) {
    switch (slug) {
      // Water
      case 'still-water':
        return '<path d="M12 2C12 2 5 10 5 14a7 7 0 0 0 14 0c0-4-7-12-7-12z" fill="currentColor"/>'
            '<path d="M9 14a3 3 0 0 0 3 3" stroke="white" stroke-width="1.4" stroke-linecap="round" fill="none" opacity="0.7"/>';
      case 'sparkling-water':
        return '<path d="M12 4C12 4 6 11 6 14.5a6 6 0 0 0 12 0C18 11 12 4 12 4z" fill="currentColor"/>'
            '<circle cx="9" cy="14" r="1" fill="white" opacity="0.85"/>'
            '<circle cx="13.5" cy="11.5" r="0.7" fill="white" opacity="0.85"/>'
            '<circle cx="14.5" cy="15.5" r="1.2" fill="white" opacity="0.85"/>'
            '<circle cx="10.5" cy="17" r="0.6" fill="white" opacity="0.85"/>';
      case 'mineral-water':
        return '<path d="M12 3l4 5-4 13-4-13 4-5z" fill="currentColor"/>'
            '<path d="M8 8h8M12 3v18" stroke="white" stroke-width="0.7" opacity="0.6"/>';

      // Coffee
      case 'espresso':
        return '<path d="M7 9h8a2 2 0 0 1 2 2v3a4 4 0 0 1-4 4h-4a4 4 0 0 1-4-4v-3a2 2 0 0 1 2-2z" fill="currentColor"/>'
            '<path d="M17 11h1.5a1.5 1.5 0 0 1 0 3H17" stroke="currentColor" stroke-width="1.5" fill="none"/>'
            '<path d="M9 6c0 1 1 1 1 2M12 6c0 1 1 1 1 2" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" fill="none"/>';
      case 'americano':
        return '<path d="M6 7h11v9a4 4 0 0 1-4 4h-3a4 4 0 0 1-4-4V7z" fill="currentColor"/>'
            '<path d="M17 9h1.5a1.5 1.5 0 0 1 0 3H17" stroke="currentColor" stroke-width="1.5" fill="none"/>'
            '<ellipse cx="11.5" cy="11" rx="3.5" ry="1" fill="white" opacity="0.6"/>';
      case 'latte':
        return '<path d="M7 5h10v13a4 4 0 0 1-4 4h-2a4 4 0 0 1-4-4V5z" fill="currentColor"/>'
            '<path d="M7 9h10" stroke="white" stroke-width="1.5" opacity="0.75"/>'
            '<ellipse cx="12" cy="6.5" rx="3.5" ry="1" fill="white" opacity="0.85"/>';
      case 'cappuccino':
        return '<path d="M6 9h12v5a5 5 0 0 1-5 5h-2a5 5 0 0 1-5-5V9z" fill="currentColor"/>'
            '<path d="M18 11h1.5a1.5 1.5 0 0 1 0 3H18" stroke="currentColor" stroke-width="1.5" fill="none"/>'
            '<path d="M9 8c0-1 1-1 1.5-2M12 8c0-1 1-1 1.5-2M15 8c0-1 1-1 1.5-2" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" fill="none"/>';

      // Tea
      case 'green-tea':
        return '<path d="M5 9h13v5a5 5 0 0 1-5 5h-3a5 5 0 0 1-5-5V9z" fill="currentColor"/>'
            '<path d="M18 11h1.5a1.5 1.5 0 0 1 0 3H18" stroke="currentColor" stroke-width="1.5" fill="none"/>'
            '<path d="M11 7c0-2 2-3 4-2-0.5 2-2 3-4 2z" fill="white" opacity="0.85"/>';
      case 'black-tea':
        return '<path d="M5 9h13v5a5 5 0 0 1-5 5h-3a5 5 0 0 1-5-5V9z" fill="currentColor"/>'
            '<path d="M18 11h1.5a1.5 1.5 0 0 1 0 3H18" stroke="currentColor" stroke-width="1.5" fill="none"/>'
            '<path d="M9 6c0 1 1 1 1 2M12 6c0 1 1 1 1 2M15 6c0 1 1 1 1 2" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" fill="none"/>';
      case 'herbal-tea':
        return '<path d="M5 9h13v5a5 5 0 0 1-5 5h-3a5 5 0 0 1-5-5V9z" fill="currentColor"/>'
            '<path d="M18 11h1.5a1.5 1.5 0 0 1 0 3H18" stroke="currentColor" stroke-width="1.5" fill="none"/>'
            '<path d="M11 5c0 2 1 3 3 3M11 5c-1 1-1 3 0 4M14 8c0-1 0-3-3-3" fill="none" stroke="white" stroke-width="1.4" stroke-linecap="round" opacity="0.85"/>';

      // Juice
      case 'orange-juice':
        return '<path d="M7 4h10l-1 16a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2L7 4z" fill="currentColor"/>'
            '<circle cx="12" cy="9" r="2.5" fill="white" opacity="0.85"/>'
            '<path d="M12 6.5v5M9.5 9h5M10.2 7.2l3.6 3.6M10.2 10.8l3.6-3.6" stroke="currentColor" stroke-width="0.7" opacity="0.4"/>';
      case 'apple-juice':
        return '<path d="M7 4h10l-1 16a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2L7 4z" fill="currentColor"/>'
            '<path d="M12 7c-1.5 0-2.5 1-2.5 2.5 0 1.5 1 3 2.5 3.5 1.5-0.5 2.5-2 2.5-3.5C14.5 8 13.5 7 12 7z" fill="white" opacity="0.85"/>'
            '<path d="M12 7v-1l1-1" stroke="currentColor" stroke-width="0.8" stroke-linecap="round" opacity="0.6"/>';
      case 'smoothie':
        return '<path d="M7 6h10l-1 14a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2L7 6z" fill="currentColor"/>'
            '<rect x="13" y="2" width="2" height="10" rx="1" fill="white" opacity="0.85"/>'
            '<circle cx="10" cy="14" r="1" fill="white" opacity="0.6"/>'
            '<circle cx="13" cy="17" r="0.8" fill="white" opacity="0.6"/>';

      // Soda
      case 'cola':
        return '<path d="M7 4h10v17a2 2 0 0 1-2 2h-6a2 2 0 0 1-2-2V4z" fill="currentColor"/>'
            '<path d="M7 8h10" stroke="white" stroke-width="1.2" opacity="0.7"/>'
            '<path d="M9 4v-2h6v2" fill="currentColor"/>'
            '<path d="M10 12h4" stroke="white" stroke-width="0.8" opacity="0.6"/>';
      case 'lemonade':
        return '<path d="M7 4h10l-1 16a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2L7 4z" fill="currentColor"/>'
            '<circle cx="12" cy="10" r="2.5" fill="white" opacity="0.85"/>'
            '<path d="M12 7.5v5M9.5 10h5M10.5 8.5l3 3M10.5 11.5l3-3" stroke="currentColor" stroke-width="0.6" opacity="0.5"/>';

      // Dairy
      case 'milk':
        return '<path d="M9 2h6v3l1.5 2.5a2 2 0 0 1 0.5 1.5V20a2 2 0 0 1-2 2H9a2 2 0 0 1-2-2V9a2 2 0 0 1 0.5-1.5L9 5V2z" fill="currentColor"/>'
            '<rect x="8.5" y="13" width="7" height="4" fill="white" opacity="0.85"/>';
      case 'kefir':
        return '<path d="M9 2h6v3l1.5 2.5a2 2 0 0 1 0.5 1.5V20a2 2 0 0 1-2 2H9a2 2 0 0 1-2-2V9a2 2 0 0 1 0.5-1.5L9 5V2z" fill="currentColor"/>'
            '<rect x="8.5" y="11" width="7" height="6" fill="white" opacity="0.85"/>'
            '<circle cx="11" cy="14" r="0.5" fill="currentColor" opacity="0.6"/>'
            '<circle cx="13.5" cy="15" r="0.5" fill="currentColor" opacity="0.6"/>';

      // Sports
      case 'isotonic':
        return '<path d="M10 2h4v3a3 3 0 0 1 1 2v13a2 2 0 0 1-2 2h-2a2 2 0 0 1-2-2V7a3 3 0 0 1 1-2V2z" fill="currentColor"/>'
            '<path d="M10.5 10h3v6h-3z" fill="white" opacity="0.85"/>'
            '<path d="M11 4h2" stroke="white" stroke-width="1" opacity="0.6"/>';
      case 'energy-drink':
        return '<path d="M7 4h10v17a2 2 0 0 1-2 2h-6a2 2 0 0 1-2-2V4z" fill="currentColor"/>'
            '<path d="M9 4v-2h6v2" fill="currentColor"/>'
            '<path d="M13 9l-3 5h2l-1 4 3-5h-2l1-4z" fill="white" opacity="0.95"/>';

      // Alcohol
      case 'beer':
        return '<path d="M6 8h10v12a2 2 0 0 1-2 2h-6a2 2 0 0 1-2-2V8z" fill="currentColor"/>'
            '<path d="M16 10h2a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2h-2" stroke="currentColor" stroke-width="1.5" fill="none"/>'
            '<path d="M5 8c0-2 2-3 3-2 1-2 3-2 4 0 1-1 3 0 3 2H5z" fill="white" opacity="0.95"/>';
      case 'wine':
        return '<path d="M7 3h10c0 4-2 8-5 8s-5-4-5-8z" fill="currentColor"/>'
            '<path d="M12 11v8M9 21h6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>';

      // Other
      case 'broth':
        return '<path d="M3 11h18l-1.5 6a3 3 0 0 1-3 2.5h-9a3 3 0 0 1-3-2.5L3 11z" fill="currentColor"/>'
            '<path d="M3 11h18" stroke="currentColor" stroke-width="1.5"/>'
            '<path d="M9 7c0 1.5 1 1.5 1 3M12 6c0 1.5 1 1.5 1 3M15 7c0 1.5 1 1.5 1 3" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" fill="none"/>';
      case 'coconut-water':
        return '<circle cx="12" cy="13" r="8" fill="currentColor"/>'
            '<circle cx="9.5" cy="11" r="1.2" fill="white" opacity="0.85"/>'
            '<circle cx="13" cy="10" r="1.2" fill="white" opacity="0.85"/>'
            '<circle cx="11.5" cy="13.5" r="1.2" fill="white" opacity="0.85"/>'
            '<path d="M10 4l1 2M13 3l-0.5 2.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" fill="none"/>';

      // Generic — water glass
      default:
        return '<path d="M7 4h10l-1 16a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2L7 4z" fill="currentColor"/>'
            '<path d="M8 9h8" stroke="white" stroke-width="1.2" opacity="0.7"/>';
    }
  }
}

/// Parse the backend's #RRGGBB hex string into a Color. Returns null
/// when the input is null/empty/invalid.
Color? parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var s = hex.replaceAll('#', '');
  if (s.length == 6) s = 'FF$s';
  final v = int.tryParse(s, radix: 16);
  return v == null ? null : Color(v);
}

/// Theme-aware variants of a drink's accent colour. The backend gives
/// us a single hex (e.g. milk = #F9FAFB which is essentially white).
/// Using that directly for both text and chip backgrounds produces
/// the "invisible amount" bug — white text on a white-tinted chip on
/// a white card.
///
/// The strategy:
/// * `rail` keeps the original colour so the 4-pixel vertical bar
///   stays vivid against the card.
/// * `text` clamps lightness to a readable band depending on the
///   theme (dark text in light mode, light text in dark mode).
/// * `chipBg` returns a subtle background tint that always shows
///   against the surrounding card.
class DrinkColors {
  final Color rail;
  final Color text;
  final Color chipBg;
  final Color iconBg;

  const DrinkColors({
    required this.rail,
    required this.text,
    required this.chipBg,
    required this.iconBg,
  });

  factory DrinkColors.from(Color base, Brightness brightness) {
    final hsl = HSLColor.fromColor(base);
    final isLight = brightness == Brightness.light;

    // Vivid rail: if the base is washed out, give it some saturation.
    final railHsl = hsl.withSaturation(
      hsl.saturation < 0.35 ? 0.55 : hsl.saturation,
    );
    final rail = railHsl
        .withLightness(railHsl.lightness.clamp(0.35, 0.65))
        .toColor();

    // Readable text:
    //   light theme → push down to lightness 0.25-0.40
    //   dark  theme → lift up to lightness 0.55-0.75
    final text =
        (isLight ? railHsl.withLightness(0.30) : railHsl.withLightness(0.70))
            .toColor();

    // Chip background — a faint wash of the text colour.
    final chipBg = text.withValues(alpha: isLight ? 0.12 : 0.22);

    // Icon disc — like chipBg but a touch stronger so the SVG
    // foreground isn't too faint.
    final iconBg = text.withValues(alpha: isLight ? 0.15 : 0.26);

    return DrinkColors(rail: rail, text: text, chipBg: chipBg, iconBg: iconBg);
  }
}
