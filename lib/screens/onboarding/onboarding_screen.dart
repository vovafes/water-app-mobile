import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

/// First-run flow. POSTs to /profile/onboarding which is required before
/// the backend will compute a real daily target. Mirrors the four-step
/// flow described in the web app's WHAT-IS-THIS.md but compressed into a
/// single mobile screen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _sex = 'male';
  DateTime _birthDate = DateTime(
    DateTime.now().year - 30,
    DateTime.now().month,
    DateTime.now().day,
  );
  double _weight = 70;
  double _height = 175;
  String _activity = 'moderate';
  String _climate = 'temperate';
  double _sleepHours = 8;
  String _goal = 'norm';

  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final res = await ApiService.post('/profile/onboarding', {
      'sex': _sex,
      'birth_date': DateFormat('yyyy-MM-dd').format(_birthDate),
      'weight_kg': _weight.round(),
      'height_cm': _height.round(),
      'activity_level': _activity,
      'climate_type': _climate,
      'sleep_hours': _sleepHours.round(),
      'goal': _goal,
    });

    if (!mounted) return;

    if (res['success'] == true) {
      // Refresh user so onboarded_at is populated and AppRoot moves on.
      await context.read<AuthProvider>().refreshUser();
      if (!mounted) return;
      setState(() => _submitting = false);
    } else {
      final body = res['data'];
      String msg = 'Onboarding failed'.tr();
      if (body is Map) {
        if (body['message'] is String &&
            (body['message'] as String).isNotEmpty) {
          msg = body['message'] as String;
        } else if (body['errors'] is Map &&
            (body['errors'] as Map).isNotEmpty) {
          final first = (body['errors'] as Map).values.first;
          if (first is List && first.isNotEmpty) msg = first.first.toString();
        }
      }
      setState(() {
        _submitting = false;
        _error = msg;
      });
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 5),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Tell us about yourself'.tr()),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'We use this to calculate your personal water goal.'.tr(),
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 24),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: BrandColors.rose500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: BrandColors.rose500.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: BrandColors.rose500),
                  ),
                ),

              _sectionLabel('Sex'.tr()),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'male', label: Text('Male'.tr())),
                  ButtonSegment(value: 'female', label: Text('Female'.tr())),
                  ButtonSegment(value: 'other', label: Text('Other'.tr())),
                ],
                // The leading checkmark steals enough width to wrap labels
                // like "Moderate" onto two lines; the tint already signals
                // which segment is selected.
                showSelectedIcon: false,
                selected: {_sex},
                onSelectionChanged: (s) => setState(() => _sex = s.first),
              ),

              _sectionLabel('Birth date'.tr()),
              OutlinedButton.icon(
                onPressed: _pickBirthDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(DateFormat('yyyy-MM-dd').format(_birthDate)),
              ),

              _sectionLabel('${'Weight (kg)'.tr()}: ${_weight.round()} kg'),
              Slider(
                value: _weight,
                min: 30,
                max: 200,
                divisions: 170,
                onChanged: (v) => setState(() => _weight = v),
              ),

              _sectionLabel('${'Height (cm)'.tr()}: ${_height.round()} cm'),
              Slider(
                value: _height,
                min: 100,
                max: 220,
                divisions: 120,
                onChanged: (v) => setState(() => _height = v),
              ),

              _sectionLabel('Activity level'.tr()),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'low', label: Text('Low'.tr())),
                  ButtonSegment(
                    value: 'moderate',
                    label: Text('Moderate'.tr()),
                  ),
                  ButtonSegment(value: 'high', label: Text('High'.tr())),
                  ButtonSegment(value: 'athlete', label: Text('Athlete'.tr())),
                ],
                showSelectedIcon: false,
                selected: {_activity},
                onSelectionChanged: (s) => setState(() => _activity = s.first),
              ),

              _sectionLabel('Climate'.tr()),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'cold', label: Text('Cold'.tr())),
                  ButtonSegment(
                    value: 'temperate',
                    label: Text('Temperate'.tr()),
                  ),
                  ButtonSegment(value: 'hot', label: Text('Hot'.tr())),
                  ButtonSegment(
                    value: 'tropical',
                    label: Text('Tropical'.tr()),
                  ),
                ],
                showSelectedIcon: false,
                selected: {_climate},
                onSelectionChanged: (s) => setState(() => _climate = s.first),
              ),

              _sectionLabel('${'Sleep (h)'.tr()}: ${_sleepHours.round()}'),
              Slider(
                value: _sleepHours,
                min: 4,
                max: 12,
                divisions: 8,
                onChanged: (v) => setState(() => _sleepHours = v),
              ),

              _sectionLabel('Goal'.tr()),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'norm', label: Text('Norm'.tr())),
                  ButtonSegment(
                    value: 'wellbeing',
                    label: Text('Wellbeing'.tr()),
                  ),
                  ButtonSegment(value: 'routine', label: Text('Routine'.tr())),
                  ButtonSegment(
                    value: 'weight',
                    label: Text('Lose weight'.tr()),
                  ),
                ],
                showSelectedIcon: false,
                selected: {_goal},
                onSelectionChanged: (s) => setState(() => _goal = s.first),
              ),

              const SizedBox(height: 32),

              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Get started'.tr(),
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    ),
  );
}
