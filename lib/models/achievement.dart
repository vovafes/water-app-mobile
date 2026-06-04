class Achievement {
  final int id;
  final String name;
  final String description;
  final String? icon;
  final String? slug;
  final int points;
  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    this.icon,
    this.slug,
    this.points = 0,
    required this.unlocked,
    this.unlockedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      icon: json['icon']?.toString(),
      slug: json['slug']?.toString(),
      points: json['points'] is num ? (json['points'] as num).toInt() : 0,
      unlocked: json['unlocked'] == true,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.tryParse(json['unlocked_at'].toString())
          : null,
    );
  }
}
