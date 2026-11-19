import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../../widgets/legal_footer.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  // Neither is pre-ticked: consent has to be an act. The second is the explicit
  // consent the GDPR asks for before processing health-related data.
  bool _terms = false;
  bool _health = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: Text('Create account'.tr())),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Center undoes the Column's stretch, which would otherwise
              // override the square's own width.
              Center(
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 60,
                  height: 60,
                ),
              ),
              const SizedBox(height: 24),
              if (auth.error != null)
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
                    auth.error!,
                    style: const TextStyle(color: BrandColors.rose500),
                  ),
                ),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Name'.tr(),
                  prefixIcon: const Icon(Icons.person_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email'.tr(),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password'.tr(),
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ConsentRow(
                value: _terms,
                onChanged: (v) => setState(() => _terms = v),
                label: 'I accept the Terms of Use and the Privacy Policy.'.tr(),
              ),
              Wrap(
                children: [
                  TextButton(
                    onPressed: () => openExternal(
                      LegalUrls.terms(context.locale.languageCode),
                    ),
                    child: Text('Terms of Use'.tr()),
                  ),
                  TextButton(
                    onPressed: () => openExternal(
                      LegalUrls.privacy(context.locale.languageCode),
                    ),
                    child: Text('Privacy Policy'.tr()),
                  ),
                ],
              ),
              _ConsentRow(
                value: _health,
                onChanged: (v) => setState(() => _health = v),
                label:
                    'I consent to my weight, height, sex and date of birth being processed to calculate my daily water target. These are health-related data. I can withdraw this at any time by deleting my account.'
                        .tr(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: auth.loading || !_terms || !_health
                    ? null
                    : () async {
                        final ok = await context.read<AuthProvider>().register(
                          _nameCtrl.text.trim(),
                          _emailCtrl.text.trim(),
                          _passCtrl.text,
                          termsAccepted: _terms,
                          healthConsent: _health,
                        );
                        if (ok && context.mounted) Navigator.pop(context);
                      },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: auth.loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Create account'.tr(),
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A checkbox with its text beside it, tappable as a whole.
class _ConsentRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  const _ConsentRow({
    required this.value,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: cs.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
