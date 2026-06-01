import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/profile');
    if (res['success']) {
      setState(() {
        _profile = res['data']['data'] ?? res['data'];
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton.icon(
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFF2196F3),
                          child: Text(
                            (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 36, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(user?.name ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        Text(user?.email ?? '', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_profile != null) ...[
                    Card(
                      child: Column(
                        children: [
                          _tile('Daily Goal', '${_profile!['daily_goal_ml'] ?? 2000} ml', Icons.flag_outlined),
                          const Divider(height: 1),
                          _tile('Weight', '${_profile!['weight_kg'] ?? '-'} kg', Icons.monitor_weight_outlined),
                          const Divider(height: 1),
                          _tile('Activity Level', _profile!['activity_level'] ?? '-', Icons.directions_run),
                          const Divider(height: 1),
                          _tile('Climate', _profile!['climate'] ?? '-', Icons.thermostat_outlined),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _tile(String label, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1976D2)),
      title: Text(label),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
