class User {
  final int id;
  final String name;
  final String email;
  final String? locale;
  final String? timezone;
  final DateTime? onboardedAt;

  /// When the address was confirmed; null until the link in the email is used.
  final DateTime? emailVerifiedAt;

  /// Absolute URL served by the backend's `public` disk, or null when the
  /// user has no photo. Changes on every upload, so it doubles as a
  /// cache-buster.
  final String? avatarUrl;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.locale,
    this.timezone,
    this.onboardedAt,
    this.emailVerifiedAt,
    this.avatarUrl,
  });

  bool get isOnboarded => onboardedAt != null;

  /// The backend refuses everything but sign-out and "send the email again"
  /// until this is true, so the app shows only the confirmation screen.
  bool get isEmailVerified => emailVerifiedAt != null;

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
      emailVerifiedAt: parseDate(json['email_verified_at']),
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}
