class Achievement {
  final int id;
  final String name;
  final String description;
  final String? icon;

  /// Which drawn icon to use; null for achievements an admin added.
  final String? iconKey;
  final String? slug;
  final int points;
  final bool unlocked;
  final DateTime? unlockedAt;

  /// Progress toward it, as the backend counts it. [target] is at least 1.
  final int current;
  final int target;
  final int percent;

  /// 'ml' when [current] and [target] are millilitres, otherwise null.
  final String? unit;

  /// 'done', 'current' (the rung being climbed) or 'locked'.
  final String state;

  /// Unlocked since the screen was last opened: plays the unlock animation once.
  final bool isNew;

  /// Rarity from the backend: 1 everyday, 2 milestone, 3 rare. Drawn as rings.
  final int tier;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    this.icon,
    this.iconKey,
    this.slug,
    this.points = 0,
    required this.unlocked,
    this.unlockedAt,
    this.current = 0,
    this.target = 1,
    this.percent = 0,
    this.unit,
    String? state,
    this.isNew = false,
    this.tier = 1,
  }) : state = state ?? (unlocked ? 'done' : 'locked');

  /// "4 / 10", or "4,200 / 10,000 ml" for volumes.
  String progressLabel(String Function(int) format, String mlSuffix) {
    final suffix = unit == 'ml' ? ' $mlSuffix' : '';
    return '${format(current)} / ${format(target)}$suffix';
  }

  factory Achievement.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, int fallback) => v is num ? v.toInt() : fallback;
    final unlocked = json['unlocked'] == true;
    final target = asInt(json['target'], 1).clamp(1, 1 << 31);

    return Achievement(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      icon: json['icon']?.toString(),
      iconKey: json['icon_key']?.toString(),
      slug: json['slug']?.toString(),
      points: asInt(json['points'], 0),
      unlocked: unlocked,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.tryParse(json['unlocked_at'].toString())
          : null,
      current: asInt(json['current'], unlocked ? target : 0),
      target: target,
      percent: asInt(json['percent'], unlocked ? 100 : 0),
      unit: json['unit']?.toString(),
      state: json['state']?.toString(),
      isNew: json['is_new'] == true,
      tier: asInt(json['tier'], 1).clamp(1, 3),
    );
  }
}

/// One ladder: a set of related achievements climbed in order.
class AchievementGroup {
  /// English title, which doubles as the translation key.
  final String title;
  final List<Achievement> items;

  const AchievementGroup({required this.title, required this.items});

  int get unlockedCount => items.where((a) => a.unlocked).length;
}

/// Everything the achievements screen shows.
class AchievementOverview {
  final int unlocked;
  final int total;
  final int points;

  /// The rung closest to done, if any is left.
  final Achievement? next;

  /// Title of the group [next] belongs to.
  final String? nextGroup;
  final List<AchievementGroup> groups;

  const AchievementOverview({
    required this.unlocked,
    required this.total,
    required this.points,
    required this.next,
    required this.nextGroup,
    required this.groups,
  });

  /// Reads the response of `GET /achievements`.
  ///
  /// An older backend sends only the flat `achievements` list; that becomes
  /// one group with no "next goal", so the screen still works.
  factory AchievementOverview.fromJson(Map<String, dynamic> body) {
    List<Achievement> parse(dynamic raw) => raw is List
        ? raw
              .whereType<Map<String, dynamic>>()
              .map(Achievement.fromJson)
              .toList()
        : <Achievement>[];

    final rawGroups = body['groups'];
    final groups = <AchievementGroup>[];
    if (rawGroups is List) {
      for (final g in rawGroups.whereType<Map<String, dynamic>>()) {
        groups.add(
          AchievementGroup(
            title: (g['title'] ?? 'Other').toString(),
            items: parse(g['items']),
          ),
        );
      }
    }

    if (groups.isEmpty) {
      final flat = parse(body['achievements'] ?? body['data']);
      if (flat.isNotEmpty) {
        groups.add(AchievementGroup(title: 'Achievements', items: flat));
      }
    }

    final all = groups.expand((g) => g.items).toList();
    final summary = body['summary'];
    int fromSummary(String key, int fallback) =>
        summary is Map && summary[key] is num
        ? (summary[key] as num).toInt()
        : fallback;

    final nextRaw = body['next'];
    return AchievementOverview(
      unlocked: fromSummary('unlocked', all.where((a) => a.unlocked).length),
      total: fromSummary('total', all.length),
      points: fromSummary(
        'points',
        all.where((a) => a.unlocked).fold(0, (s, a) => s + a.points),
      ),
      next: nextRaw is Map<String, dynamic>
          ? Achievement.fromJson(nextRaw)
          : null,
      nextGroup: nextRaw is Map ? nextRaw['group_title']?.toString() : null,
      groups: groups,
    );
  }
}
