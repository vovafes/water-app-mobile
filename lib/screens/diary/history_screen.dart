import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/drink_log.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

/// Public state class — main.dart holds a GlobalKey<HistoryScreenState>
/// so it can call refresh() when the History tab becomes active.
class HistoryScreenState extends State<HistoryScreen> {
  List<DrinkLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Public entry point for parent tab manager.
  Future<void> refresh() => _load();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final res = await ApiService.get('/drink-logs?per_page=50');
    if (!mounted) return;
    if (res['success'] == true) {
      final body = res['data'];
      // Laravel paginate() returns { data: [...], current_page, ... }.
      List rawList;
      if (body is Map && body['data'] is List) {
        rawList = body['data'] as List;
      } else if (body is List) {
        rawList = body;
      } else {
        rawList = const [];
      }
      setState(() {
        _logs = rawList
            .whereType<Map<String, dynamic>>()
            .map(DrinkLog.fromJson)
            .toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Map<String, List<DrinkLog>> get _grouped {
    final map = <String, List<DrinkLog>>{};
    for (final log in _logs) {
      final key = DateFormat('EEEE, MMM d').format(log.consumedAt);
      map.putIfAbsent(key, () => []).add(log);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grouped = _grouped;
    return Scaffold(
      appBar: AppBar(title: const Text('Drink History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text('No history yet',
                            style: TextStyle(
                                color: cs.onSurface
                                    .withValues(alpha: 0.6))),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: grouped.entries.map((entry) {
                      final total = entry.value
                          .fold(0.0, (s, l) => s + l.volumeMl);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              Text('${total.toInt()} ml',
                                  style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...entry.value.map((log) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: cs.primaryContainer,
                                  child: const Text('💧'),
                                ),
                                title: Text(log.drinkName),
                                subtitle: Text(DateFormat('HH:mm')
                                    .format(log.consumedAt)),
                                trailing: Text(
                                    '${log.volumeMl.toInt()} ml',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              )),
                          const Divider(height: 24),
                        ],
                      );
                    }).toList(),
                  ),
                ),
    );
  }
}
