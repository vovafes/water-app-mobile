class Drink {
  final int id;
  final String name;
  final String? icon;
  final double hydrationCoefficient;
  final int defaultAmount;

  Drink({
    required this.id,
    required this.name,
    this.icon,
    required this.hydrationCoefficient,
    required this.defaultAmount,
  });

  factory Drink.fromJson(Map<String, dynamic> json) {
    return Drink(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
      hydrationCoefficient: (json['hydration_coefficient'] ?? 1.0 as num).toDouble(),
      defaultAmount: json['default_amount'] ?? 250,
    );
  }
}
