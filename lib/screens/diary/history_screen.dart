import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/api_service.dart';
import '../../models/drink_log.dart';
import '../../theme.dart';
import '../../widgets/drink_icon.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<DrinkLog> _logs = [];
  bool _loading = true;

  /// Entries come a page at a time. It used to ask for the 200 newest and
  /// stop, so after a few weeks of regular logging the oldest entries just
  /// vanished from the "All" view.
  static const _pageSize = 50;
  int _page = 1;
  int _lastPage = 1;
  bool _loadingMore = false;

  // Date range filter — null on both means "all" (last 50 entries).
  DateTime? _from;
  DateTime? _to;

  // Which preset chip to highlight. 'custom' once the range comes from the
  // picker, since that never matches a preset exactly.
  String _activeRange = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final result = await _fetchPage(1);

    if (!mounted) return;
    setState(() {
      if (result != null) {
        _logs = result.logs;
        _page = 1;
        _lastPage = result.lastPage;
      }
      _loading = false;
    });
  }

  /// One page of entries for the current range, or null when the request failed.
  Future<({List<DrinkLog> logs, int lastPage})?> _fetchPage(int page) async {
    final params = <String>['per_page=$_pageSize', 'page=$page'];
    if (_from != null) {
      params.add('from=${DateFormat('yyyy-MM-dd').format(_from!)}');
    }
    if (_to != null) {
      params.add('to=${DateFormat('yyyy-MM-dd').format(_to!)}');
    }
    final res = await ApiService.get('/drink-logs?${params.join('&')}');
    if (res['success'] != true) return null;

    final body = res['data'];
    final List rawList = body is Map && body['data'] is List
        ? body['data'] as List
        : body is List
        ? body
        : const [];
    final last = body is Map && body['last_page'] is num
        ? (body['last_page'] as num).toInt()
        : page;
    return (
      logs: rawList
          .whereType<Map<String, dynamic>>()
          .map(DrinkLog.fromJson)
          .toList(),
      lastPage: last,
    );
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    final result = await _fetchPage(_page + 1);
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (result == null) return;
      // An entry logged or deleted meanwhile shifts the pages by one; do not
      // show the same entry twice.
      final seen = _logs.map((l) => l.id).toSet();
      _logs = [..._logs, ...result.logs.where((l) => !seen.contains(l.id))];
      _page += 1;
      _lastPage = result.lastPage;
    });
  }

  /// Asks first, then removes the entry on the server and drops it from the
  /// list. Resolves true only when it is really gone, which is what lets the
  /// swipe animation finish; on failure the row springs back and says why.
  ///
  /// There was no way to undo a mistaken entry on the phone at all (a 3000 ml
  /// typo stayed in the day's total for good), although the API has had a
  /// DELETE route from the start.
  Future<bool> _deleteLog(DrinkLog log) async {
    final dash = context.read<DashboardProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final failure = 'Could not delete the entry'.tr();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete this entry?'.tr()),
        content: Text(
          'This removes it from your history and your daily total.'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text('Delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    final res = await ApiService.delete('/drink-logs/${log.id}');
    if (res['success'] != true) {
      messenger.showSnackBar(
        SnackBar(content: Text(failure), backgroundColor: errorColor),
      );
      return false;
    }
    HapticFeedback.lightImpact();
    // Today's ring and totals live in another provider; without this the
    // dashboard kept showing the deleted drink until the next refresh.
    dash.loadDashboard(silent: true);
    return true;
  }

  /// Drops a deleted entry from the list. Called once the swipe has finished
  /// (a Dismissible has to leave the tree from its own onDismissed).
  void _removeLog(DrinkLog log) {
    if (!mounted) return;
    setState(() => _logs = _logs.where((l) => l.id != log.id).toList());
  }

  Map<String, List<DrinkLog>> _grouped(String localeCode) {
    final map = <String, List<DrinkLog>>{};
    for (final log in _logs) {
      final key = DateFormat.MMMMEEEEd(localeCode).format(log.consumedAt);
      map.putIfAbsent(key, () => []).add(log);
    }
    return map;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
      saveText: 'Apply'.tr(),
    );
    if (result != null) {
      setState(() {
        _from = result.start;
        _to = result.end;
        _activeRange = 'custom';
      });
      _load();
    }
  }

  void _setQuickRange(int? days) {
    setState(() {
      _activeRange = days?.toString() ?? 'all';
      if (days == null) {
        _from = null;
        _to = null;
      } else {
        final now = DateTime.now();
        _to = DateTime(now.year, now.month, now.day);
        _from = _to!.subtract(Duration(days: days - 1));
      }
    });
    _load();
  }

  String _rangeLabel(String localeCode) {
    if (_from == null || _to == null) return 'All time'.tr();
    final fmt = DateFormat.MMMd(localeCode);
    if (_from!.year == _to!.year &&
        _from!.month == _to!.month &&
        _from!.day == _to!.day) {
      return fmt.format(_from!);
    }
    return '${fmt.format(_from!)} – ${fmt.format(_to!)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final localeCode = context.locale.languageCode;
    final grouped = _grouped(localeCode);

    return Scaffold(
      appBar: AppBar(
        title: Text('History'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: _pickRange,
            tooltip: 'Pick date range'.tr(),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            label: _rangeLabel(localeCode),
            active: _activeRange,
            onClear: _from != null ? () => _setQuickRange(null) : null,
            onQuick: _setQuickRange,
            onPickRange: _pickRange,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                ? RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.event_note_outlined,
                                size: 48,
                                color: cs.outline,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No drinks in this range'.tr(),
                                style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final (i, entry) in grouped.entries.indexed)
                          _DayBlock(
                            label: entry.key,
                            // While more pages are waiting, the oldest day shown
                            // may be cut off mid-day, so its total would be
                            // wrong. Better no number than a wrong one.
                            total:
                                (_page < _lastPage && i == grouped.length - 1)
                                ? null
                                : entry.value
                                      .fold(0.0, (s, l) => s + l.volumeMl)
                                      .toInt(),
                            logs: entry.value,
                            onDelete: _deleteLog,
                            onDeleted: _removeLog,
                          ),
                        if (_page < _lastPage)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 24),
                            child: OutlinedButton(
                              onPressed: _loadingMore ? null : _loadMore,
                              child: _loadingMore
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text('Load more'.tr()),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String label;
  final String active;
  final VoidCallback? onClear;
  final ValueChanged<int?> onQuick;
  final VoidCallback onPickRange;

  const _FilterBar({
    required this.label,
    required this.active,
    required this.onClear,
    required this.onQuick,
    required this.onPickRange,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: cs.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (onClear != null)
                TextButton(onPressed: onClear, child: Text('Clear'.tr())),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _quickChip('Today'.tr(), '1', () => onQuick(1)),
                const SizedBox(width: 6),
                _quickChip('7 days'.tr(), '7', () => onQuick(7)),
                const SizedBox(width: 6),
                _quickChip('30 days'.tr(), '30', () => onQuick(30)),
                const SizedBox(width: 6),
                _quickChip('All'.tr(), 'all', () => onQuick(null)),
                const SizedBox(width: 6),
                ChoiceChip(
                  avatar: const Icon(Icons.date_range, size: 16),
                  label: Text('Custom'.tr()),
                  selected: active == 'custom',
                  showCheckmark: false,
                  onSelected: (_) => onPickRange(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChip(String label, String key, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: active == key,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    );
  }
}

class _DayBlock extends StatelessWidget {
  final String label;

  /// Null while the day may be incomplete (more pages still to load).
  final int? total;
  final List<DrinkLog> logs;
  final Future<bool> Function(DrinkLog log) onDelete;
  final void Function(DrinkLog log) onDeleted;
  const _DayBlock({
    required this.label,
    required this.total,
    required this.logs,
    required this.onDelete,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (total != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$total ${'ml'.tr()}',
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ...logs.map((log) {
                final raw = parseHexColor(log.drinkColor) ?? BrandColors.sky500;
                final tone = DrinkColors.from(
                  raw,
                  Theme.of(context).brightness,
                );
                final row = Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 38,
                        decoration: BoxDecoration(
                          color: tone.rail,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: tone.iconBg,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: DrinkIcon(
                          slug: log.drinkSlug ?? _guessSlug(log.drinkName),
                          color: tone.text,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(log.drinkName),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              DateFormat('HH:mm').format(log.consumedAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: tone.chipBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${log.volumeMl.toInt()} ${'ml'.tr()}',
                          style: TextStyle(
                            color: tone.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                // Swipe left to delete; screen readers get the same thing as a
                // named action, since a swipe is not available to them.
                return Semantics(
                  customSemanticsActions: {
                    CustomSemanticsAction(label: 'Delete'.tr()): () async {
                      if (await onDelete(log)) onDeleted(log);
                    },
                  },
                  child: Dismissible(
                    key: ValueKey('log-${log.id}'),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => onDelete(log),
                    onDismissed: (_) => onDeleted(log),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.delete_outline, color: cs.error),
                    ),
                    child: row,
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String? _guessSlug(String name) {
    final n = name.toLowerCase();
    if (n.contains('sparkling')) return 'sparkling-water';
    if (n.contains('mineral')) return 'mineral-water';
    if (n.contains('water')) return 'still-water';
    if (n.contains('espresso')) return 'espresso';
    if (n.contains('americano')) return 'americano';
    if (n.contains('latte')) return 'latte';
    if (n.contains('cappuccino') || n.contains('capp')) return 'cappuccino';
    if (n.contains('green tea')) return 'green-tea';
    if (n.contains('black tea')) return 'black-tea';
    if (n.contains('herbal') || n.contains('tea')) return 'herbal-tea';
    if (n.contains('orange juice')) return 'orange-juice';
    if (n.contains('apple juice')) return 'apple-juice';
    if (n.contains('smoothie')) return 'smoothie';
    if (n.contains('cola')) return 'cola';
    if (n.contains('lemon')) return 'lemonade';
    if (n.contains('kefir')) return 'kefir';
    if (n.contains('milk')) return 'milk';
    if (n.contains('isotonic')) return 'isotonic';
    if (n.contains('energy')) return 'energy-drink';
    if (n.contains('beer')) return 'beer';
    if (n.contains('wine')) return 'wine';
    if (n.contains('broth')) return 'broth';
    if (n.contains('coconut')) return 'coconut-water';
    return null;
  }
}
