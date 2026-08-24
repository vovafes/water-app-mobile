import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  // Raw articles, not resolved _Tip objects: the locale is applied in
  // build() so switching language re-renders without a refetch.
  List<Map<String, dynamic>> _raw = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    // Backend returns title/summary/body as locale-keyed JSON; we
    // pick the right language client-side in _Tip.fromJson.
    final res = await ApiService.get('/tips');

    if (!mounted) return;
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
        _raw = rawList.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _error = 'Could not load tips'.tr();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = context.locale.languageCode;
    final tips = _raw.map((j) => _Tip.fromJson(j, locale)).toList();
    return Scaffold(
      appBar: AppBar(title: Text('Tips'.tr())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: tips.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Column(
                            children: [
                              const Text('💡', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 8),
                              Text(
                                _error ??
                                    'No tips available in your language yet.'
                                        .tr(),
                                style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: tips.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _TipCard(
                          tip: tips[i],
                          onTap: () => _openReader(context, tips[i]),
                        ),
                      ),
                    ),
            ),
    );
  }

  void _openReader(BuildContext context, _Tip tip) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _TipReader(tip: tip)),
    );
  }
}

/// One feed-style card with cover image, category chip, title and a
/// preview of the body.
class _TipCard extends StatelessWidget {
  final _Tip tip;
  final VoidCallback onTap;
  const _TipCard({required this.tip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image, or sky-gradient placeholder if there's no
            // cover.
            AspectRatio(
              aspectRatio: 16 / 9,
              child: tip.coverUrl != null
                  ? Image.network(
                      tip.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _CoverPlaceholder(),
                      loadingBuilder: (ctx, child, p) => p == null
                          ? child
                          : Container(
                              color: cs.surfaceContainerHigh,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                    )
                  : const _CoverPlaceholder(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (tip.category != null)
                        _CategoryChip(label: tip.category!),
                      const Spacer(),
                      Text(
                        'Read more'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right, size: 16, color: cs.primary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tip.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  if (tip.summary != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      tip.summary!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: cs.onSurface.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandColors.sky400, BrandColors.cyan500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: const Text('💧', style: TextStyle(fontSize: 64)),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  const _CategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        // Categories come from the API, so this is a runtime key: an
        // unknown one falls through to its own (English) name.
        context.tr(label),
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Full-screen article reader.
class _TipReader extends StatelessWidget {
  final _Tip tip;
  const _TipReader({required this.tip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: 240,
            pinned: true,
            // Dark, so the white back arrow and light status-bar icons stay
            // readable both over the cover and once the bar collapses.
            backgroundColor: BrandColors.slate900,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (tip.coverUrl != null)
                    Image.network(
                      tip.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _CoverPlaceholder(),
                    )
                  else
                    const _CoverPlaceholder(),
                  // Bottom gradient so the back button stays readable
                  // over light covers.
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (tip.category != null) ...[
                  _CategoryChip(label: tip.category!),
                  const SizedBox(height: 12),
                ],
                Text(
                  tip.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                    height: 1.2,
                  ),
                ),
                if (tip.summary != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    tip.summary!,
                    style: TextStyle(
                      fontSize: 15,
                      color: cs.onSurface.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  tip.body,
                  style: const TextStyle(fontSize: 15, height: 1.6),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tip {
  final String title;
  final String? summary;
  final String body;
  final String? coverPath;
  final String? category;

  const _Tip({
    required this.title,
    this.summary,
    required this.body,
    this.coverPath,
    this.category,
  });

  String? get coverUrl {
    if (coverPath == null || coverPath!.isEmpty) return null;
    return '${ApiService.assetBaseUrl}/$coverPath';
  }

  factory _Tip.fromJson(Map<String, dynamic> json, String preferred) {
    return _Tip(
      title:
          _readI18n(json['title'] ?? json['localized_title'], preferred) ??
          'Untitled'.tr(),
      summary: _readI18n(
        json['summary'] ?? json['localized_summary'],
        preferred,
      ),
      body:
          _readI18n(
            json['body'] ?? json['localized_body'] ?? json['content'],
            preferred,
          ) ??
          '',
      coverPath: json['cover_image']?.toString(),
      category: _categoryKey(json['category']?.toString()),
    );
  }

  /// The API stores categories lower-cased ("routine", "science") while the
  /// locale files key them capitalised, mirroring the web's
  /// `__(ucfirst($a->category))`. Without this the chip renders the raw
  /// English slug in every language.
  static String? _categoryKey(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return raw[0].toUpperCase() + raw.substring(1);
  }

  /// title/summary/body are JSON keyed by locale (en/de/ru/uk). Prefer
  /// the user's active locale, fall back to English, then any other
  /// non-empty value.
  static String? _readI18n(dynamic v, String preferred) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    if (v is Map) {
      final order = <String>{preferred, 'en', 'de', 'ru', 'uk'};
      for (final lang in order) {
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
