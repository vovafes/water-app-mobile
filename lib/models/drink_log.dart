class DrinkLog {
  final int id;
  final int? drinkId;
  final String drinkName;
  final String? drinkColor;
  final String? drinkIconPath;
  final double volumeMl;
  final double hydrationMl;
  final DateTime consumedAt;

  const DrinkLog({
    required this.id,
    this.drinkId,
    required this.drinkName,
    this.drinkColor,
    this.drinkIconPath,
    required this.volumeMl,
    required this.hydrationMl,
    required this.consumedAt,
  });

  /// Backwards-compatible accessors so older UI code that asked for `amount`
  /// or `loggedAt` keeps working.
  double get amount => volumeMl;
  DateTime get loggedAt => consumedAt;

  /// The dashboard's "recent_logs" returns a flat shape:
  ///   { id, drink_id, drink_name, drink_color, volume_ml, hydration_ml, consumed_at }
  /// The drink-logs index returns a nested shape:
  ///   { id, drink_id, volume_ml, hydration_ml, consumed_at, drink: { name, color, icon_path } }
  /// Both are handled here.
  factory DrinkLog.fromJson(Map<String, dynamic> json) {
    final drink = json['drink'];

    String? readNested(String key) {
      if (drink is Map) {
        final v = drink[key];
        if (v != null) return v.toString();
      }
      return null;
    }

    final name = json['drink_name']?.toString() ??
        readNested('name') ??
        'Drink';

    final color = json['drink_color']?.toString() ?? readNested('color');
    final iconPath =
        json['drink_icon_path']?.toString() ?? readNested('icon_path');

    final volume = (json['volume_ml'] ?? json['amount'] ?? 0) as num;
    final hydration = (json['hydration_ml'] ??
        json['water_equivalent'] ??
        volume) as num;

    final consumedRaw = json['consumed_at'] ??
        json['logged_at'] ??
        json['created_at'];
    final consumedAt = consumedRaw != null
        ? DateTime.tryParse(consumedRaw.toString())?.toLocal() ?? DateTime.now()
        : DateTime.now();

    return DrinkLog(
      id: (json['id'] as num).toInt(),
      drinkId: json['drink_id'] is num
          ? (json['drink_id'] as num).toInt()
          : (drink is Map && drink['id'] is num
              ? (drink['id'] as num).toInt()
              : null),
      drinkName: name,
      drinkColor: color,
      drinkIconPath: iconPath,
      volumeMl: volume.toDouble(),
      hydrationMl: hydration.toDouble(),
      consumedAt: consumedAt,
    );
  }
}
