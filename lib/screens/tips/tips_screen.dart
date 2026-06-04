import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  List<_Tip> _tips = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.get('/tips');
    if (res['success'] == true) {
      final body = res['data'];
      List rawList;
      if (body is Map && body['articles'] is List) {
        rawList = body['articles'] as List;
      } else if (body is Map && body['data'] is List) {
        rawList = body['data'] as List;
      } else if (body is List) {
        rawList = body;
      } else {
        rawList = const [];
      }
      setState(() {
        _tips = rawList
            .whereType<Map<String, dynamic>>()
            .map(_Tip.fromJson)
            .toList();
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _error = 'Could not load tips';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hydration Tips')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _tips.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(_error ?? 'No tips yet',
                              style: const TextStyle(color: Colors.grey)),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tips.length,
                      itemBuilder: (context, i) {
                        final tip = _tips[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ExpansionTile(
                            leading: const Icon(Icons.lightbulb_outline,
                                color: Colors.amber),
                            title: Text(tip.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: tip.summary != null
                                ? Text(tip.summary!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis)
                                : null,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Text(tip.body),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _Tip {
  final String title;
  final String? summary;
  final String body;
  const _Tip({required this.title, this.summary, required this.body});

  factory _Tip.fromJson(Map<String, dynamic> json) {
    return _Tip(
      title: _readI18n(json['title'] ?? json['localized_title']) ?? 'Untitled',
      summary: _readI18n(json['summary'] ?? json['localized_summary']),
      body: _readI18n(json['body'] ?? json['localized_body'] ?? json['content']) ??
          '',
    );
  }

  /// Title/summary/body on the backend are stored as JSON keyed by locale
  /// (en/de/ru/uk). When Laravel returns them as Map, we pull the best
  /// available language; if they're already a String, just return it.
  static String? _readI18n(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    if (v is Map) {
      for (final lang in ['en', 'de', 'ru', 'uk']) {
        final s = v[lang];
        if (s is String && s.isNotEmpty) return s;
      }
      for (final s in v.values) {
        if (s is String && s.isNotEmpty) return s;
      }
    }
    return null;
  }
}
