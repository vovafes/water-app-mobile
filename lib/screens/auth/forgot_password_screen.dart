import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';

/// Asks for the email address and has the server mail a link for choosing a
/// new password. The link opens the website's reset page in the phone's
/// browser, so nothing here needs a session.
///
/// The confirmation is worded as "if that address has an account": the server
/// answers the same either way, and so must this screen, or the form turns into
/// a way to list who is registered.
class ForgotPasswordScreen extends StatefulWidget {
  /// Whatever was already typed on the sign-in form.
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (email.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await context.read<AuthProvider>().requestPasswordReset(
      email,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      switch (result.outcome) {
        case PasswordResetOutcome.sent:
          _sent = true;
        case PasswordResetOutcome.throttled:
          _error = 'Too many attempts. Wait a minute and try again.'.tr();
        case PasswordResetOutcome.invalid:
          _error = result.message;
        case PasswordResetOutcome.failed:
          _error =
              'Could not send the link. Check your connection and try again.'
                  .tr();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('Reset your password'.tr())),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _sent ? _confirmation(cs) : _form(cs),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Enter the email you signed up with. We'll send you a link to choose a new password."
              .tr(),
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
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
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.send,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _send(),
          decoration: InputDecoration(
            labelText: 'Email'.tr(),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _sending || _email.text.trim().isEmpty ? null : _send,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _sending
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Send reset link'.tr(),
                  style: const TextStyle(fontSize: 16),
                ),
        ),
      ],
    );
  }

  Widget _confirmation(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: BrandColors.sky500.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 34,
            color: BrandColors.sky500,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Check your email'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          'If that address has an account, a reset link is on its way. Look in your spam folder too.'
              .tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'Back to sign in'.tr(),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
