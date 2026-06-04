import '../services/api_service.dart';

class Drink {
  final int id;
  final String name;
  final String? slug;
  final String? color;
  final String? iconPath;
  final String? categorySlug;
  final double hydrationMultiplier;
  final List<int> defaultVolumes;

  const Drink({
    required this.id,
    required this.name,
    this.slug,
    this.color,
    this.iconPath,
    this.categorySlug,
    required this.hydrationMultiplier,
    required this.defaultVolumes,
  });

  /// Convenience: default volume to log when the user just taps the chip.
  int get defaultVolumeMl => defaultVolumes.isNotEmpty ? defaultVolumes.first : 250;

  /// Absolute URL for the icon image, or null if the drink has no icon.
  String? get iconUrl {
    if (iconPath == null || iconPath!.isEmpty) return null;
    return '${ApiService.assetBaseUrl}/$iconPath';
  }

  /// A small emoji fallback for the chip when there's no icon image — keyed
  /// off the category slug. This keeps the UI presentable until icon images
  /// load.
  String get emojiFallback {
    switch (categorySlug) {
      case 'water':
        return '💧';
      case 'coffee':
        return '☕';
      case 'tea':
        return '🍵';
      case 'juice':
        return '🧃';
      case 'soft-drink':
      case 'soda':
        return '🥤';
      case 'alcohol':
      case 'beer':
        return '🍺';
      case 'milk':
        return '🥛';
      case 'sports':
        return '🥤';
      default:
        return '🥤';
    }
  }

  factory Drink.fromJson(Map<String, dynamic> json) {
    final volumes = json['default_volumes'];
    final List<int> parsed = volumes is List
        ? volumes.map((e) => (e as num).toInt()).toList()
        : <int>[200, 250, 330];

    return Drink(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      slug: json['slug']?.toString(),
      color: json['color']?.toString(),
      iconPath: json['icon_path']?.toString(),
      categorySlug: json['category']?.toString(),
      hydrationMultiplier:
          ((json['hydration_multiplier'] ?? 1.0) as num).toDouble(),
      defaultVolumes: parsed.isNotEmpty ? parsed : <int>[200, 250, 330],
    );
  }
}
