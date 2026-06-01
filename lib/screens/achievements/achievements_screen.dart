import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/achievement.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<Achievement> _achievements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/achievements');
    if (res['success']) {
      final list = res['data']['data'] ?? res['data'];
      setState(() {
        _achievements = (list as List).map((e) => Achievement.fromJson(e)).toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _achievements.where((a) => a.unlocked).toList();
    final locked = _achievements.where((a) => !a.unlocked).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (unlocked.isNotEmpty) ...[
                    Text('Unlocked (${unlocked.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...unlocked.map((a) => _AchievementCard(a: a)),
                    const SizedBox(height: 16),
                  ],
                  if (locked.isNotEmpty) ...[
                    Text('Locked (${locked.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    ...locked.map((a) => _AchievementCard(a: a)),
                  ],
                ],
              ),
            ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement a;
  const _AchievementCard({required this.a});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: a.unlocked ? const Color(0xFFFFF9C4) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: a.unlocked ? Colors.amber.shade100 : Colors.grey.shade100,
          child: Text(a.icon ?? (a.unlocked ? '🏆' : '🔒'),
              style: const TextStyle(fontSize: 20)),
        ),
        title: Text(a.name, style: TextStyle(
          fontWeight: FontWeight.bold,
          color: a.unlocked ? Colors.black : Colors.grey,
        )),
        subtitle: Text(a.description),
        trailing: a.unlocked
            ? const Icon(Icons.check_circle, color: Colors.amber)
            : const Icon(Icons.lock_outline, color: Colors.grey),
      ),
    );
  }
}
