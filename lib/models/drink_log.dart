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
  /// Both are handled here. Numeric fields are tolerated as both number
  /// and string because Eloquent decimal columns serialise as strings.
  factory DrinkLog.fromJson(Map<String, dynamic> json) {
    final drink = json['drink'];

    String? readNested(String key) {
      if (drink is Map) {
        final v = drink[key];
        if (v != null) return v.toString();
      }
      return null;
    }

    final name =
        json['drink_name']?.toString() ?? readNested('name') ?? 'Drink';
    final color = json['drink_color']?.toString() ?? readNested('color');
    final iconPath =
        json['drink_icon_path']?.toString() ?? readNested('icon_path');

    final volume = _readDouble(json['volume_ml'] ?? json['amount']) ?? 0;
    final hydration =
        _readDouble(json['hydration_ml'] ?? json['water_equivalent']) ?? volume;

    final consumedRaw =
        json['consumed_at'] ?? json['logged_at'] ?? json['created_at'];
    final consumedAt = consumedRaw != null
        ? DateTime.tryParse(consumedRaw.toString())?.toLocal() ?? DateTime.now()
        : DateTime.now();

    int? drinkId = _readInt(json['drink_id']);
    if (drinkId == null && drink is Map) {
      drinkId = _readInt(drink['id']);
    }

    return DrinkLog(
      id: _readInt(json['id']) ?? 0,
      drinkId: drinkId,
      drinkName: name,
      drinkColor: color,
      drinkIconPath: iconPath,
      volumeMl: volume,
      hydrationMl: hydration,
      consumedAt: consumedAt,
    );
  }
}

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
