import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../reminders/reminders_screen.dart';

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

  Future<void> _logout() async {
    // Cancel scheduled notifications first so the next account on this
    // device does not inherit the previous user's reminders.
    await context.read<ReminderProvider>().clear();
    if (!mounted) return;
    await context.read<AuthProvider>().logout();
  }

  /// Google Play requires this path to exist in-app for any app that lets
  /// users register in-app. Deletion is irreversible and cascades over
  /// every log, so it asks for the password rather than a bare "are you
  /// sure" — the same bar the web's delete-user form sets.
  Future<void> _deleteAccount() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete account'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // One literal, deliberately not split across lines: the i18n
            // guard test reads the key straight out of the source, and
            // adjacent-string concatenation would hide half of it.
            Text(
              'This permanently deletes your account and all of your data. This cannot be undone.'
                  .tr(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Password'.tr(),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: BrandColors.rose500),
            child: Text('Delete account'.tr()),
          ),
        ],
      ),
    );

    final password = controller.text;
    controller.dispose();
    if (confirmed != true || password.isEmpty || !mounted) return;

    // Drop the local notification queue before the account goes away, or
    // the phone keeps nagging on behalf of a user that no longer exists.
    await context.read<ReminderProvider>().clear();
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.deleteAccount(password);
    if (!mounted) return;

    // On success main.dart routes back to login on its own, because the
    // provider has already cleared the user.
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Could not delete your account'.tr()),
          backgroundColor: BrandColors.rose500,
        ),
      );
    }
  }

  Future<void> _changeLanguage(String code) async {
    final loc = Locale(code);
    await context.setLocale(loc);
    if (!mounted) return;
    await _saveField({'locale': code});
    if (!mounted) return;
    // Notification bodies are baked in at schedule time, so everything
    // already queued would keep nagging in the old language. Reload from
    // the API (rather than resyncing the in-memory list, which is empty
    // until the Reminders screen has been opened at least once) so the
    // whole set is rebuilt with the new locale's copy.
    await context.read<ReminderProvider>().load();
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
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
                          leading: const Icon(
                            Icons.tune,
                            color: BrandColors.sky500,
                          ),
                          title: Text('Goal'.tr()),
                          trailing: SegmentedButton<String>(
                            segments: [
                              ButtonSegment(
                                value: 'auto',
                                label: Text('Auto'.tr()),
                              ),
                              ButtonSegment(
                                value: 'manual',
                                label: Text('Manual'.tr()),
                              ),
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
                            label: '${'Daily goal'.tr()} (ml)',
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
                          onChanged: (v) => _saveField({'activity_level': v}),
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
                          onChanged: (v) => _saveField({'climate_type': v}),
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
                  _SectionTitle(title: 'Notifications'.tr()),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.notifications_active_outlined,
                        color: BrandColors.sky500,
                      ),
                      title: Text('Reminders'.tr()),
                      subtitle: Text('Nudges to drink through the day'.tr()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RemindersScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(title: 'Appearance'.tr()),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(switch (theme.mode) {
                            ThemeMode.light => Icons.light_mode,
                            ThemeMode.dark => Icons.dark_mode,
                            ThemeMode.system => Icons.brightness_auto,
                          }, color: cs.primary),
                          title: Text('Theme'.tr()),
                          trailing: SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon: Icon(Icons.light_mode, size: 18),
                              ),
                              ButtonSegment(
                                value: ThemeMode.system,
                                icon: Icon(Icons.brightness_auto, size: 18),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: Icon(Icons.dark_mode, size: 18),
                              ),
                            ],
                            selected: {theme.mode},
                            onSelectionChanged: (s) =>
                                context.read<ThemeProvider>().setMode(s.first),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.language, color: cs.primary),
                          title: Text('Language'.tr()),
                          subtitle: Text(_languageLabel(currentLocale)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final picked = await showModalBottomSheet<String>(
                              context: context,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              builder: (ctx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        'Your language'.tr(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    for (final entry in _languages.entries)
                                      ListTile(
                                        title: Text(entry.value),
                                        trailing: entry.key == currentLocale
                                            ? const Icon(
                                                Icons.check,
                                                color: BrandColors.sky500,
                                              )
                                            : null,
                                        onTap: () =>
                                            Navigator.pop(ctx, entry.key),
                                      ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            );
                            if (picked != null && picked != currentLocale) {
                              await _changeLanguage(picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: Text('Log out'.tr()),
                    style: FilledButton.styleFrom(
                      backgroundColor: BrandColors.rose500,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete_forever_outlined, size: 20),
                    label: Text('Delete account'.tr()),
                    style: TextButton.styleFrom(
                      foregroundColor: BrandColors.rose500,
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

class _Header extends StatefulWidget {
  final User? user;
  const _Header({required this.user});

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _busy = false;

  Future<void> _pickPhoto() async {
    if (_busy) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Change photo'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: BrandColors.sky500,
              ),
              title: Text('Take a photo'.tr()),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: BrandColors.sky500,
              ),
              title: Text('Choose from gallery'.tr()),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (widget.user?.avatarUrl != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: BrandColors.rose500,
                ),
                title: Text('Remove photo'.tr()),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    String? path;
    if (action != 'remove') {
      final picked = await ImagePicker().pickImage(
        source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
        // The backend re-crops to 512², so anything larger is wasted upload.
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (picked == null) return;
      path = picked.path;
    }
    if (!mounted) return;

    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final ok = path == null
        ? await auth.removeAvatar()
        : await auth.uploadAvatar(path);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Could not update your photo'.tr()),
          backgroundColor: BrandColors.rose500,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final avatarUrl = user?.avatarUrl;

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickPhoto,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [BrandColors.sky400, BrandColors.cyan500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    image: avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: avatarUrl != null
                      ? null
                      : Text(
                          (user?.name.isNotEmpty == true)
                              ? user!.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 36,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.photo_camera_outlined,
                          size: 16,
                          color: BrandColors.sky500,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            user?.name ?? '',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Text(
            user?.email ?? '',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
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
    child: Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    ),
  );
}

class _ReadTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ReadTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: BrandColors.sky500),
    title: Text(label),
    trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
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
      subtitle: Text(
        options[value] ?? value,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...options.entries.map(
                  (e) => ListTile(
                    title: Text(e.value),
                    trailing: e.key == value
                        ? const Icon(Icons.check, color: BrandColors.sky500)
                        : null,
                    onTap: () => Navigator.pop(ctx, e.key),
                  ),
                ),
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
      subtitle: Text(
        '$value',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        int current = value;
        final picked = await showModalBottomSheet<int>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$current',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Slider(
                      value: current.toDouble(),
                      min: min.toDouble(),
                      max: max.toDouble(),
                      divisions: ((max - min) / step).round(),
                      onChanged: (v) => setSt(() => current = v.round()),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel'.tr()),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, current),
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
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
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
