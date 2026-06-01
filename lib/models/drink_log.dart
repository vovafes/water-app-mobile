class DrinkLog {
  final int id;
  final String drinkName;
  final String? drinkIcon;
  final double amount;
  final double waterEquivalent;
  final DateTime loggedAt;

  DrinkLog({
    required this.id,
    required this.drinkName,
    this.drinkIcon,
    required this.amount,
    required this.waterEquivalent,
    required this.loggedAt,
  });

  factory DrinkLog.fromJson(Map<String, dynamic> json) {
    return DrinkLog(
      id: json['id'],
      drinkName: json['drink']?['name'] ?? json['drink_name'] ?? 'Unknown',
      drinkIcon: json['drink']?['icon'],
      amount: (json['amount'] as num).toDouble(),
      waterEquivalent: (json['water_equivalent'] ?? json['amount'] as num).toDouble(),
      loggedAt: DateTime.parse(json['logged_at'] ?? json['created_at']),
    );
  }
}
