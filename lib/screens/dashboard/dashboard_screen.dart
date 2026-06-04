import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/drink.dart';
import '../../theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEEE, MMM d').format(DateTime.now())),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => dash.loadDashboard(),
          ),
        ],
      ),
      body: dash.loading && dash.recentLogs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: dash.loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _HeroCard(dash: dash),
                  const SizedBox(height: 16),
                  _DrinkPicker(dash: dash),
                  const SizedBox(height: 16),
                  _RecentLogsCard(dash: dash),
                ],
              ),
            ),
    );
  }
}

/// Sky → cyan gradient card with the progress ring, big consumed/target
/// number, and a streak chip. Mirrors the web app's hero block.
class _HeroCard extends StatelessWidget {
  final DashboardProvider dash;
  const _HeroCard({required this.dash});

  @override
  Widget build(BuildContext context) {
    final pct = (dash.progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [BrandColors.gradientStartStrong, BrandColors.gradientEndStrong],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: BrandColors.sky500.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -40,
            child: Text(
              '💧',
              style: TextStyle(
                fontSize: 160,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CircularProgressIndicator(
                        value: dash.progress,
                        strokeWidth: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        color: Colors.white,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$pct%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700)),
                        Text('today',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: '${dash.consumedMl.toInt()}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              height: 1.1),
                        ),
                        TextSpan(
                          text: ' / ${dash.targetMl.toInt()} ml',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 4),
                    Text('of daily goal',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥'),
                          const SizedBox(width: 6),
                          Text(
                            '${dash.streak} day streak',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Pick a drink" — search field + grid of all drinks the backend
/// returned. Tapping a drink opens the volume bottom sheet.
class _DrinkPicker extends StatefulWidget {
  final DashboardProvider dash;
  const _DrinkPicker({required this.dash});

  @override
  State<_DrinkPicker> createState() => _DrinkPickerState();
}

class _DrinkPickerState extends State<_DrinkPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.dash.drinks
        : widget.dash.drinks
            .where((d) =>
                d.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pick a drink',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search drinks…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 16),
            if (widget.dash.drinks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: Text('No drinks match.',
                        style: TextStyle(color: BrandColors.slate500))),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, i) => _DrinkTile(
                  drink: filtered[i],
                  onTap: () => _openVolumeSheet(filtered[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openVolumeSheet(Drink drink) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _VolumeSheet(drink: drink, dash: widget.dash),
    );
  }
}

class _DrinkTile extends StatelessWidget {
  final Drink drink;
  final VoidCallback onTap;
  const _DrinkTile({required this.drink, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _parseHex(drink.color) ?? BrandColors.sky500;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(drink.emojiFallback,
                  style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(height: 6),
            Text(
              drink.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: preset volume chips + custom volume input.
/// Matches the web's modal layout.
class _VolumeSheet extends StatefulWidget {
  final Drink drink;
  final DashboardProvider dash;
  const _VolumeSheet({required this.drink, required this.dash});

  @override
  State<_VolumeSheet> createState() => _VolumeSheetState();
}

class _VolumeSheetState extends State<_VolumeSheet> {
  final TextEditingController _custom = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _log(int ml) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final ok = await widget.dash.logDrink(widget.drink.id, ml.toDouble());
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '$ml ml logged 💧' : 'Failed to log drink'),
      backgroundColor: ok
          ? BrandColors.emerald500
          : Theme.of(context).colorScheme.error,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final drink = widget.drink;
    final color = _parseHex(drink.color) ?? BrandColors.sky500;
    final volumes = drink.defaultVolumes.isNotEmpty
        ? drink.defaultVolumes
        : const [200, 250, 330, 500];
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(drink.emojiFallback,
                    style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(drink.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(
                      '${drink.hydrationMultiplier.toStringAsFixed(drink.hydrationMultiplier == drink.hydrationMultiplier.roundToDouble() ? 0 : 2)}× hydration',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Choose amount',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
            ),
            itemCount: volumes.length,
            itemBuilder: (context, i) {
              final v = volumes[i];
              return InkWell(
                onTap: _submitting ? null : () => _log(v),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outline),
                  ),
                  alignment: Alignment.center,
                  child: Text('$v ml',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Custom amount',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _custom,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'ml',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _submitting
                    ? null
                    : () {
                        final v = int.tryParse(_custom.text);
                        if (v == null || v < 10 || v > 5000) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Enter 10–5000 ml')));
                          return;
                        }
                        _log(v);
                      },
                child: const Text('Log'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentLogsCard extends StatelessWidget {
  final DashboardProvider dash;
  const _RecentLogsCard({required this.dash});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent logs',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                if (dash.recentLogs.isNotEmpty)
                  Text('${dash.logsCount} · ${dash.consumedMl.toInt()} ml',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6))),
              ],
            ),
            const SizedBox(height: 8),
            if (dash.recentLogs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No drinks logged today yet.\nPick one above to get started!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.55)),
                  ),
                ),
              )
            else
              ...dash.recentLogs.map((log) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: const Text('💧'),
                    ),
                    title: Text(log.drinkName),
                    subtitle: Text(
                        DateFormat('HH:mm').format(log.consumedAt)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${log.volumeMl.toInt()} ml',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.primary)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 20),
                          color: BrandColors.rose500,
                          onPressed: () => dash.deleteDrinkLog(log.id),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

Color? _parseHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var s = hex.replaceAll('#', '');
  if (s.length == 6) s = 'FF$s';
  final v = int.tryParse(s, radix: 16);
  return v == null ? null : Color(v);
}
