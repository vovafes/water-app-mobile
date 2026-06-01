import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/drink.dart';
import 'package:intl/intl.dart';

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
      context.read<DashboardProvider>().loadDrinks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEEE, MMM d').format(DateTime.now())),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => dash.loadDashboard(),
          ),
        ],
      ),
      body: dash.loading && dash.todayLogs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: dash.loadDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProgressCard(dash: dash),
                    const SizedBox(height: 16),
                    _QuickLogSection(dash: dash),
                    const SizedBox(height: 16),
                    _TodayLogsList(dash: dash),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final DashboardProvider dash;
  const _ProgressCard({required this.dash});

  @override
  Widget build(BuildContext context) {
    final pct = (dash.progress * 100).toInt();
    return Card(
      elevation: 0,
      color: const Color(0xFFE3F2FD),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Today\'s Intake', style: TextStyle(color: Colors.blueGrey)),
                    Text(
                      '${dash.todayIntake.toInt()} ml',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                    ),
                    Text('of ${dash.dailyGoal.toInt()} ml goal',
                        style: const TextStyle(color: Colors.blueGrey)),
                  ],
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: dash.progress,
                        strokeWidth: 8,
                        backgroundColor: Colors.blue.shade100,
                        color: const Color(0xFF1976D2),
                      ),
                    ),
                    Text('$pct%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: dash.progress,
              backgroundColor: Colors.blue.shade100,
              color: const Color(0xFF1976D2),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLogSection extends StatelessWidget {
  final DashboardProvider dash;
  const _QuickLogSection({required this.dash});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (dash.drinks.isEmpty)
          const Center(child: CircularProgressIndicator())
        else
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dash.drinks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _DrinkChip(drink: dash.drinks[i], dash: dash),
            ),
          ),
      ],
    );
  }
}

class _DrinkChip extends StatelessWidget {
  final Drink drink;
  final DashboardProvider dash;
  const _DrinkChip({required this.drink, required this.dash});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAmountDialog(context),
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(drink.icon ?? '💧', style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(drink.name, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${drink.defaultAmount}ml', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _showAmountDialog(BuildContext context) {
    double amount = drink.defaultAmount.toDouble();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log ${drink.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(drink.icon ?? '💧', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  Text('${amount.toInt()} ml', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Slider(
                    value: amount,
                    min: 50,
                    max: 1000,
                    divisions: 19,
                    onChanged: (v) => setState(() => amount = v),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [100, 200, 250, 500].map((ml) =>
                      TextButton(
                        onPressed: () => setState(() => amount = ml.toDouble()),
                        child: Text('${ml}ml'),
                      ),
                    ).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await dash.logDrink(drink.id, amount);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? '${amount.toInt()}ml logged! 💧' : 'Failed to log drink'),
                  backgroundColor: ok ? Colors.green : Colors.red,
                ));
              }
            },
            child: const Text('Log'),
          ),
        ],
      ),
    );
  }
}

class _TodayLogsList extends StatelessWidget {
  final DashboardProvider dash;
  const _TodayLogsList({required this.dash});

  @override
  Widget build(BuildContext context) {
    if (dash.todayLogs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Text('💧', style: TextStyle(fontSize: 48)),
              SizedBox(height: 8),
              Text('No drinks logged today', style: TextStyle(color: Colors.grey)),
              Text('Tap a drink above to get started!', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Today\'s Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...dash.todayLogs.map((log) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: Text(log.drinkIcon ?? '💧'),
          ),
          title: Text(log.drinkName),
          subtitle: Text(DateFormat('HH:mm').format(log.loggedAt)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${log.amount.toInt()} ml',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () => dash.deleteDrinkLog(log.id),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
