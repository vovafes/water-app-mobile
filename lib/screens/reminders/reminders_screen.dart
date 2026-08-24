import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/reminder.dart';
import '../../premium/premium_gate.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../theme.dart';
import '../../widgets/premium_prompt.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderProvider>().load();
    });
  }

  Future<void> _openEditor([Reminder? existing]) async {
    final provider = context.read<ReminderProvider>();

    // The most earned paywall in the app: the user already has a schedule
    // running and wants a second one. Editing an existing reminder is never
    // gated — taking away something already set up is a different and much
    // worse experience than declining to add another.
    if (existing == null) {
      final limit = context.read<AuthProvider>().gate.reminderLimit;
      if (limit != null && provider.reminders.length >= limit) {
        final bought = await showPremiumPrompt(
          context,
          PremiumFeature.moreReminders,
          source: 'reminders',
        );
        if (!bought) return;
        if (!mounted) return;
      }
    }

    if (!mounted) return;
    final result = await Navigator.of(context).push<Reminder>(
      MaterialPageRoute(builder: (_) => ReminderEditScreen(reminder: existing)),
    );
    if (result == null) return;

    final ok = existing == null
        ? await provider.create(result)
        : await provider.update(result);
    if (!ok && mounted) _toast(provider.error ?? 'Could not save'.tr());
  }

  Future<void> _delete(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete reminder?'.tr()),
        content: Text(reminder.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BrandColors.rose500),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<ReminderProvider>();
    final ok = await provider.remove(reminder.id);
    if (!ok && mounted) _toast(provider.error ?? 'Could not save'.tr());
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: BrandColors.rose500),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReminderProvider>();

    return Scaffold(
      appBar: AppBar(title: Text('Reminders'.tr())),
      // The empty state carries its own "New reminder" button, so the FAB
      // would be a second copy of the same action on the same screen.
      floatingActionButton: provider.reminders.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_alert_outlined),
              label: Text('New reminder'.tr()),
            ),
      body: provider.loading && provider.reminders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: provider.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  if (!provider.permissionGranted) ...[
                    _PermissionCard(
                      onGrant: () => provider.requestPermission(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (provider.reminders.isEmpty)
                    _EmptyState(onCreate: () => _openEditor())
                  else
                    for (final reminder in provider.reminders) ...[
                      _ReminderCard(
                        reminder: reminder,
                        onTap: () => _openEditor(reminder),
                        onDelete: () => _delete(reminder),
                        onToggle: (active) => provider.update(
                          reminder.copyWith(isActive: active),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final VoidCallback onGrant;
  const _PermissionCard({required this.onGrant});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_off_outlined,
                color: BrandColors.amber500,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Notifications are turned off'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Allow notifications so your reminders can reach you.'.tr(),
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onGrant,
            child: Text('Allow notifications'.tr()),
          ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 64),
    child: Column(
      children: [
        const Icon(
          Icons.notifications_none,
          size: 56,
          color: BrandColors.sky400,
        ),
        const SizedBox(height: 12),
        Text(
          'No reminders yet'.tr(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Set one up and we will nudge you through the day.'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: Text('New reminder'.tr()),
        ),
      ],
    ),
  );
}

class _ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _ReminderCard({
    required this.reminder,
    required this.onTap,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scheduleSummary(context, reminder),
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                    if (!reminder.everyDay) ...[
                      const SizedBox(height: 2),
                      Text(
                        weekdaySummary(context, reminder.daysOfWeek),
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(value: reminder.isActive, onChanged: onToggle),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: BrandColors.rose500,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editor
// ---------------------------------------------------------------------------

class ReminderEditScreen extends StatefulWidget {
  final Reminder? reminder;
  const ReminderEditScreen({super.key, this.reminder});

  @override
  State<ReminderEditScreen> createState() => _ReminderEditScreenState();
}

class _ReminderEditScreenState extends State<ReminderEditScreen> {
  late final TextEditingController _title;
  late ReminderType _type;
  late int _intervalMinutes;
  late List<String> _fixedTimes;
  late String? _quietStart;
  late String? _quietEnd;
  late List<int> _days;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    _title = TextEditingController(
      text: r?.title ?? 'Time to drink water'.tr(),
    );
    _type = r?.type == ReminderType.fixed
        ? ReminderType.fixed
        : ReminderType.interval;
    _intervalMinutes = r?.intervalMinutes ?? 90;
    _fixedTimes = List<String>.from(
      r?.fixedTimes ?? const ['09:00', '13:00', '18:00'],
    );
    // A fresh reminder gets a sane sleep window rather than firing at 03:00.
    _quietStart = r?.quietHoursStart ?? (r == null ? '22:00' : null);
    _quietEnd = r?.quietHoursEnd ?? (r == null ? '07:00' : null);
    _days = List<int>.from(r?.daysOfWeek ?? const <int>[]);
    _isActive = r?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Reminder _build() => Reminder(
    id: widget.reminder?.id ?? 0,
    title: _title.text.trim().isEmpty
        ? 'Time to drink water'.tr()
        : _title.text.trim(),
    type: _type,
    intervalMinutes: _intervalMinutes,
    fixedTimes: _type == ReminderType.fixed ? _fixedTimes : const [],
    quietHoursStart: _quietStart,
    quietHoursEnd: _quietEnd,
    daysOfWeek: _days.length >= 7 ? const [] : _days,
    channel: widget.reminder?.channel ?? 'push',
    isActive: _isActive,
  );

  Future<void> _pickTime({
    required String? initial,
    required ValueChanged<String> onPicked,
  }) async {
    final minutes = minutesOfDay(initial) ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked != null) onPicked(formatHm(picked.hour * 60 + picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.reminder == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New reminder'.tr() : 'Edit reminder'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Title'.tr()),
          ),
          const SizedBox(height: 20),
          _SectionLabel('Schedule'.tr()),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SegmentedButton<ReminderType>(
                    segments: [
                      ButtonSegment(
                        value: ReminderType.interval,
                        label: Text('Interval'.tr()),
                      ),
                      ButtonSegment(
                        value: ReminderType.fixed,
                        label: Text('Fixed times'.tr()),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() => _type = s.first),
                  ),
                ),
                const Divider(height: 1),
                if (_type == ReminderType.interval)
                  _IntervalTile(
                    minutes: _intervalMinutes,
                    onChanged: (v) => setState(() => _intervalMinutes = v),
                  )
                else
                  _FixedTimesTile(
                    times: _fixedTimes,
                    onAdd: () => _pickTime(
                      initial: null,
                      onPicked: (t) => setState(() {
                        if (!_fixedTimes.contains(t)) {
                          _fixedTimes = [..._fixedTimes, t]..sort();
                        }
                      }),
                    ),
                    onRemove: (t) => setState(
                      () => _fixedTimes = _fixedTimes
                          .where((x) => x != t)
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel('Quiet hours'.tr()),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(
                    Icons.bedtime_outlined,
                    color: BrandColors.sky500,
                  ),
                  title: Text('Pause overnight'.tr()),
                  value: _quietStart != null && _quietEnd != null,
                  onChanged: (on) => setState(() {
                    _quietStart = on ? '22:00' : null;
                    _quietEnd = on ? '07:00' : null;
                  }),
                ),
                if (_quietStart != null && _quietEnd != null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.nightlight_round,
                      color: BrandColors.sky500,
                    ),
                    title: Text('From'.tr()),
                    trailing: Text(
                      _quietStart!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () => _pickTime(
                      initial: _quietStart,
                      onPicked: (t) => setState(() => _quietStart = t),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.wb_sunny_outlined,
                      color: BrandColors.sky500,
                    ),
                    title: Text('Until'.tr()),
                    trailing: Text(
                      _quietEnd!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () => _pickTime(
                      initial: _quietEnd,
                      onPicked: (t) => setState(() => _quietEnd = t),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel('Repeat on'.tr()),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      label: Text(weekdayLabel(context, day)),
                      selected: _days.isEmpty || _days.contains(day),
                      onSelected: (on) => setState(() {
                        // An empty list means "every day" on the wire, so
                        // expand it before toggling one day off.
                        final next = _days.isEmpty
                            ? [1, 2, 3, 4, 5, 6, 7]
                            : [..._days];
                        if (on) {
                          if (!next.contains(day)) next.add(day);
                        } else {
                          if (next.length == 1) return;
                          next.remove(day);
                        }
                        next.sort();
                        _days = next;
                      }),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: SwitchListTile(
              secondary: const Icon(
                Icons.notifications_active_outlined,
                color: BrandColors.sky500,
              ),
              title: Text('Enabled'.tr()),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => Navigator.pop(context, _build()),
            child: Text('Save'.tr()),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    ),
  );
}

class _IntervalTile extends StatelessWidget {
  final int minutes;
  final ValueChanged<int> onChanged;
  const _IntervalTile({required this.minutes, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Every {} min'.tr(args: ['$minutes']),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Slider(
          value: minutes.toDouble(),
          min: Reminder.minIntervalMinutes.toDouble(),
          max: Reminder.maxIntervalMinutes.toDouble(),
          divisions:
              (Reminder.maxIntervalMinutes - Reminder.minIntervalMinutes) ~/ 15,
          label: '$minutes',
          onChanged: (v) {
            final snapped = (v / 15).round() * 15;
            // A detent the finger can feel. Fired only when the value
            // actually changes, or dragging would buzz continuously.
            if (snapped != minutes) HapticFeedback.selectionClick();
            onChanged(snapped);
          },
        ),
      ],
    ),
  );
}

class _FixedTimesTile extends StatelessWidget {
  final List<String> times;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const _FixedTimesTile({
    required this.times,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final time in times)
          InputChip(label: Text(time), onDeleted: () => onRemove(time)),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: Text('Add time'.tr()),
          onPressed: onAdd,
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Shared formatting
// ---------------------------------------------------------------------------

/// Localized short weekday name for an ISO weekday (1 = Monday).
/// 2024-01-01 was a Monday, so day N of that week lines up exactly.
String weekdayLabel(BuildContext context, int isoWeekday) => DateFormat.E(
  context.locale.languageCode,
).format(DateTime(2024, 1, isoWeekday));

String weekdaySummary(BuildContext context, List<int> days) =>
    days.map((d) => weekdayLabel(context, d)).join(', ');

String scheduleSummary(BuildContext context, Reminder reminder) {
  final parts = <String>[];
  if (reminder.type == ReminderType.fixed) {
    parts.add(
      reminder.fixedTimes.isEmpty
          ? 'No times set'.tr()
          : reminder.fixedTimes.join(', '),
    );
  } else {
    parts.add('Every {} min'.tr(args: ['${reminder.intervalMinutes}']));
  }
  if (reminder.hasQuietHours) {
    parts.add(
      'quiet {}–{}'.tr(
        args: [reminder.quietHoursStart!, reminder.quietHoursEnd!],
      ),
    );
  }
  return parts.join(' · ');
}
