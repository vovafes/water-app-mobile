class User {
  final int id;
  final String name;
  final String email;
  final String? locale;
  final String? timezone;
  final DateTime? onboardedAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.locale,
    this.timezone,
    this.onboardedAt,
  });

  bool get isOnboarded => onboardedAt != null;

  factory User.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return User(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      locale: json['locale']?.toString(),
      timezone: json['timezone']?.toString(),
      onboardedAt: parseDate(json['onboarded_at']),
    );
  }
}
