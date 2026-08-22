import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/entitlement.dart';

/// Last known entitlement, cached so a bad network does not demote a
/// paying user.
///
/// The backend stays the source of truth — this is only what the app falls
/// back to while it cannot reach it. Without the cache, one trip through a
/// tunnel turns Premium off mid-session, which reads as a bug and gets
/// written up as one.
///
/// The TTL is the other half of that trade. A cache with no expiry means a
/// cancelled subscription keeps working forever on a device that never
/// goes online; seven days is long enough to cover any plausible offline
/// stretch and short enough that a lapsed account resolves itself.
class EntitlementStore {
  static const _key = 'entitlement_cache';
  static const _stampKey = 'entitlement_cached_at';
  static const ttl = Duration(days: 7);

  static Future<void> save(Entitlement e) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(e.toJson()));
    await prefs.setString(_stampKey, DateTime.now().toIso8601String());
  }

  /// Returns [Entitlement.free] when there is no cache, when it cannot be
  /// read, or when it is older than [ttl].
  static Future<Entitlement> read() async {
    final prefs = await SharedPreferences.getInstance();
    final stamp = DateTime.tryParse(prefs.getString(_stampKey) ?? '');
    if (stamp == null || DateTime.now().difference(stamp) > ttl) {
      return Entitlement.free;
    }
    final raw = prefs.getString(_key);
    if (raw == null) return Entitlement.free;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return Entitlement.free;
      return Entitlement.fromJson(decoded);
    } catch (_) {
      return Entitlement.free;
    }
  }

  /// Called on logout and account deletion. The next account to sign in on
  /// this device must not inherit the previous one's Premium.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_stampKey);
  }
}
