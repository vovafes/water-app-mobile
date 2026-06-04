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
  int? _computedTargetMl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/profile');
    if (res['success'] == true && res['data'] is Map<String, dynamic>) {
      final body = res['data'] as Map<String, dynamic>;
      Map<String, dynamic>? profile;
      if (body['profile'] is Map<String, dynamic>) {
        profile = body['profile'] as Map<String, dynamic>;
      } else if (body['data'] is Map<String, dynamic>) {
        profile = body['data'] as Map<String, dynamic>;
      } else {
        profile = body;
      }
      setState(() {
        _profile = profile;
        _computedTargetMl = body['computed_target_ml'] is num
            ? (body['computed_target_ml'] as num).toInt()
            : null;
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
            label:
                const Text('Logout', style: TextStyle(color: Colors.red)),
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
                            (user?.name.isNotEmpty == true)
                                ? user!.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 36, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(user?.name ?? '',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        Text(user?.email ?? '',
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_profile != null) ...[
                    Card(
                      child: Column(
                        children: [
                          _tile('Daily Goal', _goalLabel(), Icons.flag_outlined),
                          const Divider(height: 1),
                          _tile('Sex', _str('sex'),
                              Icons.person_outline),
                          const Divider(height: 1),
                          _tile('Weight', _kg('weight_kg'),
                              Icons.monitor_weight_outlined),
                          const Divider(height: 1),
                          _tile('Height', _cm('height_cm'),
                              Icons.height),
                          const Divider(height: 1),
                          _tile('Activity Level', _str('activity_level'),
                              Icons.directions_run),
                          const Divider(height: 1),
                          _tile('Climate', _str('climate_type'),
                              Icons.thermostat_outlined),
                          const Divider(height: 1),
                          _tile('Goal', _str('goal'),
                              Icons.track_changes_outlined),
                        ],
                      ),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('Complete onboarding to set your goal',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  String _str(String key) {
    final v = _profile?[key];
    if (v == null) return '—';
    return v.toString();
  }

  String _kg(String key) {
    final v = _profile?[key];
    return v == null ? '—' : '$v kg';
  }

  String _cm(String key) {
    final v = _profile?[key];
    return v == null ? '—' : '$v cm';
  }

  String _goalLabel() {
    final manual = _profile?['manual_target_ml'];
    final mode = _profile?['target_mode'];
    if (mode == 'manual' && manual is num) {
      return '${manual.toInt()} ml (manual)';
    }
    if (_computedTargetMl != null) return '$_computedTargetMl ml';
    if (manual is num) return '${manual.toInt()} ml';
    return '—';
  }

  Widget _tile(String label, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1976D2)),
      title: Text(label),
      trailing: Text(value,
          style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
