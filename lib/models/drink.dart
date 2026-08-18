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

  factory Drink.fromJson(Map<String, dynamic> json) {
    // Backend returns `category` as either:
    //  - a string slug (DashboardSummaryService::popularDrinksFor flattens it)
    //  - a full nested object (DrinkController::index eager-loads `category`)
    String? readCategorySlug(dynamic v) {
      if (v == null) return null;
      if (v is String) return v;
      if (v is Map) {
        final s = v['slug'];
        if (s is String) return s;
      }
      return null;
    }

    final volumes = json['default_volumes'];
    final List<int> parsed = volumes is List
        ? volumes
            .map(_readInt)
            .whereType<int>()
            .toList()
        : <int>[];

    return Drink(
      id: _readInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      slug: json['slug']?.toString(),
      color: json['color']?.toString(),
      iconPath: json['icon_path']?.toString(),
      categorySlug: readCategorySlug(json['category']),
      // hydration_multiplier is a decimal column → Eloquent serializes
      // it as a string ("1.00"), not a number. Be tolerant.
      hydrationMultiplier:
          _readDouble(json['hydration_multiplier']) ?? 1.0,
      defaultVolumes: parsed.isNotEmpty ? parsed : <int>[200, 250, 330],
    );
  }
}

/// Helpers that tolerate the inevitable num-vs-string mismatch from
/// Eloquent's decimal serialization.
int? _readInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  return null;
}

double? _readDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
