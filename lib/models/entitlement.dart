/// Whether this account may use Premium features, as decided by the
/// backend.
///
/// The store (App Store / Play) is what *sells* the subscription, but it is
/// not what this app asks. `/auth/me` returns an `entitlement` object built
/// from the backend's own `subscriptions` table, which the stores keep
/// current over App Store Server Notifications V2 and Play RTDN. A
/// client-side `isPremium` flag would be bypassed in minutes, lost on
/// reinstall, and invisible to a second device — see MONETIZATION.md §9.
///
/// Older backends do not send the field at all. That parses to
/// [Entitlement.free], which is the correct answer: no entitlement on
/// record means no entitlement.
class Entitlement {
  /// Product family, not the specific SKU. `null` while free.
  final PremiumTier? tier;

  /// End of the paid period. Access runs to this instant even after the
  /// user cancels — cutting it off at cancellation time is what generates
  /// refund requests.
  final DateTime? expiresAt;

  /// Set while the store is retrying a failed payment (up to 16 days on
  /// both platforms). Access stays on: the card usually goes through.
  final DateTime? inGraceUntil;

  /// `app_store`, `play_store`, or `promo` for comped accounts.
  final String? source;

  /// True once the user has cancelled but before [expiresAt]. Only used to
  /// soften the copy in Profile; it does not gate anything.
  final bool cancelled;

  const Entitlement({
    this.tier,
    this.expiresAt,
    this.inGraceUntil,
    this.source,
    this.cancelled = false,
  });

  static const free = Entitlement();

  /// Lifetime has no expiry, so [expiresAt] being null is meaningful rather
  /// than missing. Every other tier without an expiry is treated as
  /// expired — a subscription the backend cannot date is not one to trust.
  bool get isActive {
    if (tier == null) return false;
    if (tier == PremiumTier.lifetime) return true;
    final until = inGraceUntil ?? expiresAt;
    if (until == null) return false;
    return until.isAfter(DateTime.now());
  }

  bool get isInGrace =>
      inGraceUntil != null && inGraceUntil!.isAfter(DateTime.now());

  factory Entitlement.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

    return Entitlement(
      tier: PremiumTier.fromWire(json['tier']?.toString()),
      expiresAt: parse(json['expires_at']),
      inGraceUntil: parse(json['in_grace_until']),
      source: json['source']?.toString(),
      cancelled: json['cancelled'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'tier': tier?.wire,
    'expires_at': expiresAt?.toIso8601String(),
    'in_grace_until': inGraceUntil?.toIso8601String(),
    'source': source,
    'cancelled': cancelled,
  };
}

enum PremiumTier {
  monthly,
  annual,
  lifetime;

  String get wire => name;

  static PremiumTier? fromWire(String? v) {
    if (v == null) return null;
    for (final t in PremiumTier.values) {
      if (t.name == v) return t;
    }
    return null;
  }
}
