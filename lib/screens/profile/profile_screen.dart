import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  int? _computedTargetMl;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final res = await ApiService.get('/profile');
    if (!mounted) return;
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

  Future<void> _saveField(Map<String, dynamic> patch) async {
    if (_saving) return;
    setState(() => _saving = true);
    final res = await ApiService.put('/profile', patch);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      // If we just patched locale, refresh the User too so
      // AuthProvider.user.locale is current.
      if (patch.containsKey('locale')) {
        await context.read<AuthProvider>().refreshUser();
      }
      await _load();
    } else {
      final body = res['data'];
      String msg = 'Could not save'.tr();
      if (body is Map) {
        if (body['message'] is String &&
            (body['message'] as String).isNotEmpty) {
          msg = body['message'] as String;
        } else if (body['errors'] is Map &&
            (body['errors'] as Map).isNotEmpty) {
          final first = (body['errors'] as Map).values.first;
          if (first is List && first.isNotEmpty) {
            msg = first.first.toString();
          }
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: BrandColors.rose500),
      );
    }
  }

  Future<void> _changeLanguage(String code) async {
    final loc = Locale(code);
    await context.setLocale(loc);
    await _saveField({'locale': code});
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final theme = context.watch<ThemeProvider>();
    final currentLocale = context.locale.languageCode;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
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
                  _Header(user: user),
                  const SizedBox(height: 20),
                  _SectionTitle(title: 'Daily goal'.tr()),
                  Card(
                    child: Column(
                      children: [
                        _ReadTile(
                          icon: Icons.flag_outlined,
                          label: 'Daily goal'.tr(),
                          value: _goalLabel(),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.tune,
                              color: BrandColors.sky500),
                          title: Text('Goal'.tr()),
                          trailing: SegmentedButton<String>(
                            segments: [
                              ButtonSegment(
                                  value: 'auto',
                                  label: Text('Auto'.tr())),
                              ButtonSegment(
                                  value: 'manual',
                                  label: Text('Manual'.tr())),
                            ],
                            selected: {
                              (_profile?['target_mode'] ?? 'auto').toString(),
                            },
                            onSelectionChanged: (s) =>
                                _saveField({'target_mode': s.first}),
                          ),
                        ),
                        if ((_profile?['target_mode'] ?? 'auto') ==
                            'manual') ...[
                          const Divider(height: 1),
                          _NumberPickerTile(
                            icon: Icons.water_drop,
                            label: 'Daily goal'.tr() + ' (ml)',
                            value: _intOf('manual_target_ml') ?? 2000,
                            min: 500,
                            max: 10000,
                            step: 100,
                            onChanged: (v) =>
                                _saveField({'manual_target_ml': v}),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(title: 'Body'.tr()),
                  Card(
                    child: Column(
                      children: [
                        _ChoiceTile(
                          icon: Icons.person_outline,
                          label: 'Sex'.tr(),
                          value: _strOf('sex') ?? 'male',
                          options: {
                            'male': 'Male'.tr(),
                            'female': 'Female'.tr(),
                            'other': 'Other'.tr(),
                          },
                          onChanged: (v) => _saveField({'sex': v}),
                        ),
                        const Divider(height: 1),
                        _DateTile(
                          icon: Icons.cake_outlined,
                          label: 'Birth date'.tr(),
                          value: _profile?['birth_date']?.toString(),
                          onChanged: (d) => _saveField({
                            'birth_date': DateFormat('yyyy-MM-dd').format(d),
                          }),
                        ),
                        const Divider(height: 1),
                        _NumberPickerTile(
                          icon: Icons.monitor_weight_outlined,
                          label: 'Weight (kg)'.tr(),
                          value: _intOf('weight_kg') ?? 70,
                          min: 25,
                          max: 300,
                          step: 1,
                          onChanged: (v) => _saveField({'weight_kg': v}),
                        ),
                        const Divider(height: 1),
                        _NumberPickerTile(
                          icon: Icons.height,
                          label: 'Height (cm)'.tr(),
                          value: _intOf('height_cm') ?? 170,
                          min: 80,
                          max: 260,
                          step: 1,
                          onChanged: (v) => _saveField({'height_cm': v}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(title: 'Lifestyle'.tr()),
                  Card(
                    child: Column(
                      children: [
                        _ChoiceTile(
                          icon: Icons.directions_run,
                          label: 'Activity'.tr(),
                          value: _strOf('activity_level') ?? 'moderate',
                          options: {
                            'low': 'Low'.tr(),
                            'moderate': 'Moderate'.tr(),
                            'high': 'High'.tr(),
                            'athlete': 'Athlete'.tr(),
                          },
                          onChanged: (v) =>
                              _saveField({'activity_level': v}),
                        ),
                        const Divider(height: 1),
                        _ChoiceTile(
                          icon: Icons.thermostat_outlined,
                          label: 'Climate'.tr(),
                          value: _strOf('climate_type') ?? 'temperate',
                          options: {
                            'cold': 'Cold'.tr(),
                            'temperate': 'Temperate'.tr(),
                            'hot': 'Hot'.tr(),
                            'tropical': 'Tropical'.tr(),
                          },
                          onChanged: (v) =>
                              _saveField({'climate_type': v}),
                        ),
                        const Divider(height: 1),
                        _NumberPickerTile(
                          icon: Icons.bedtime_outlined,
                          label: 'Sleep (h)'.tr(),
                          value: _intOf('sleep_hours') ?? 8,
                          min: 3,
                          max: 14,
                          step: 1,
                          onChanged: (v) => _saveField({'sleep_hours': v}),
                        ),
                        const Divider(height: 1),
                        _ChoiceTile(
                          icon: Icons.track_changes_outlined,
                          label: 'Goal'.tr(),
                          value: _strOf('goal') ?? 'norm',
                          options: {
                            'norm': 'Norm'.tr(),
                            'wellbeing': 'Wellbeing'.tr(),
                            'routine': 'Routine'.tr(),
                            'weight': 'Lose weight'.tr(),
                          },
                          onChanged: (v) => _saveField({'goal': v}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(title: 'Appearance'.tr()),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            switch (theme.mode) {
                              ThemeMode.light => Icons.light_mode,
                              ThemeMode.dark => Icons.dark_mode,
                              ThemeMode.system => Icons.brightness_auto,
                            },
                            color: cs.primary,
                          ),
                          title: Text('Theme'.tr()),
                          trailing: SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon:
                                    Icon(Icons.light_mode, size: 18),
                              ),
                              ButtonSegment(
                                value: ThemeMode.system,
                                icon: Icon(
                                    Icons.brightness_auto,
                                    size: 18),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: Icon(Icons.dark_mode, size: 18),
                              ),
                            ],
                            selected: {theme.mode},
                            onSelectionChanged: (s) => context
                                .read<ThemeProvider>()
                                .setMode(s.first),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.language,
                              color: cs.primary),
                          title: Text('Language'.tr()),
                          subtitle: Text(_languageLabel(currentLocale)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final picked = await showModalBottomSheet<String>(
                              context: context,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20)),
                              ),
                              builder: (ctx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text('Your language'.tr(),
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight:
                                                  FontWeight.w600)),
                                    ),
                                    for (final entry in _languages.entries)
                                      ListTile(
                                        title: Text(entry.value),
                                        trailing: entry.key == currentLocale
                                            ? const Icon(Icons.check,
                                                color:
                                                    BrandColors.sky500)
                                            : null,
                                        onTap: () =>
                                            Navigator.pop(ctx, entry.key),
                                      ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            );
                            if (picked != null &&
                                picked != currentLocale) {
                              await _changeLanguage(picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () =>
                        context.read<AuthProvider>().logout(),
                    icon: const Icon(Icons.logout),
                    label: Text('Log out'.tr()),
                    style: FilledButton.styleFrom(
                      backgroundColor: BrandColors.rose500,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  static const _languages = <String, String>{
    'en': 'English',
    'de': 'Deutsch',
    'ru': 'Русский',
    'uk': 'Українська',
  };

  String _languageLabel(String code) => _languages[code] ?? code;

  String? _strOf(String key) {
    final v = _profile?[key];
    return v?.toString();
  }

  int? _intOf(String key) {
    final v = _profile?[key];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  String _goalLabel() {
    final manual = _profile?['manual_target_ml'];
    final mode = _profile?['target_mode'];
    if (mode == 'manual' && manual is num) {
      return '${manual.toInt()} ml (${'Manual'.tr().toLowerCase()})';
    }
    if (_computedTargetMl != null) {
      return '$_computedTargetMl ml (${'Auto'.tr().toLowerCase()})';
    }
    if (manual is num) return '${manual.toInt()} ml';
    return '—';
  }
}

class _Header extends StatelessWidget {
  final dynamic user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [BrandColors.sky400, BrandColors.cyan500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              (user?.name?.toString().isNotEmpty == true)
                  ? user!.name[0].toString().toUpperCase()
                  : '?',
              style: const TextStyle(
                  fontSize: 36,
                  color: Colors.white,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          Text(user?.name?.toString() ?? '',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700)),
          Text(user?.email?.toString() ?? '',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6))),
      );
}

class _ReadTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ReadTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: BrandColors.sky500),
        title: Text(label),
        trailing: Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: BrandColors.sky500),
      title: Text(label),
      subtitle: Text(options[value] ?? value,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                ...options.entries.map((e) => ListTile(
                      title: Text(e.value),
                      trailing: e.key == value
                          ? const Icon(Icons.check,
                              color: BrandColors.sky500)
                          : null,
                      onTap: () => Navigator.pop(ctx, e.key),
                    )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
        if (picked != null && picked != value) onChanged(picked);
      },
    );
  }
}

class _NumberPickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _NumberPickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: BrandColors.sky500),
      title: Text(label),
      subtitle: Text('$value',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        int current = value;
        final picked = await showModalBottomSheet<int>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setSt) => SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('$current',
                        style: const TextStyle(
                            fontSize: 36, fontWeight: FontWeight.w700)),
                    Slider(
                      value: current.toDouble(),
                      min: min.toDouble(),
                      max: max.toDouble(),
                      divisions: ((max - min) / step).round(),
                      onChanged: (v) =>
                          setSt(() => current = v.round()),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel'.tr()),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.pop(ctx, current),
                          child: Text('Save'.tr()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        if (picked != null && picked != value) onChanged(picked);
      },
    );
  }
}

class _DateTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final ValueChanged<DateTime> onChanged;

  const _DateTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = value != null ? DateTime.tryParse(value!) : null;
    return ListTile(
      leading: Icon(icon, color: BrandColors.sky500),
      title: Text(label),
      subtitle: Text(
          parsed != null
              ? DateFormat.yMMMd(context.locale.languageCode).format(parsed)
              : '—',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: parsed ?? DateTime(now.year - 30),
          firstDate: DateTime(now.year - 100),
          lastDate: DateTime(now.year - 5),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
