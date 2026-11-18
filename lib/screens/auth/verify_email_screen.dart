import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';

/// Shown to a signed-in account whose email address has not been confirmed.
///
/// The app does nothing else until it is: the backend refuses every other
/// request with 403, so this is the only screen that can work. The link in the
/// email opens in the phone's browser, so the person leaves the app and comes
/// back; coming back is detected and the check runs by itself.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  /// Matches the server's throttle (six an hour is generous; a minute between
  /// taps keeps an impatient person from using them all up).
  static const _cooldown = 45;

  Timer? _timer;
  int _wait = 0;
  bool _sending = false;
  bool _checking = false;
  String? _note;
  bool _noteIsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The mail was sent when the account was created, so the first resend
    // is not available right away.
    _startCooldown();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  /// Back from the mail app or the browser: look again without being asked.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(silent: true);
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _wait = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait = (_wait - 1).clamp(0, _cooldown));
      if (_wait == 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    if (_sending || _wait > 0) return;
    setState(() {
      _sending = true;
      _note = null;
    });
    final ok = await context.read<AuthProvider>().resendVerification();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _note = ok ? 'Email sent'.tr() : 'Could not send the email'.tr();
      _noteIsError = !ok;
    });
    if (ok) _startCooldown();
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    setState(() {
      _checking = true;
      if (!silent) _note = null;
    });
    final auth = context.read<AuthProvider>();
    await auth.refreshUser();
    if (!mounted) return;
    setState(() {
      _checking = false;
      // Confirmed: the root swaps this screen out, nothing to say. Otherwise
      // tell the person, but not when the check was only the app coming back.
      if (!silent && !(auth.user?.isEmailVerified ?? false)) {
        _note = 'Not confirmed yet. Open the link in the email, then try again.'
            .tr();
        _noteIsError = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final email = context.watch<AuthProvider>().user?.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
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
                      Icons.mark_email_unread_outlined,
                      size: 34,
                      color: BrandColors.sky500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Check your email'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We sent a confirmation link to {email}. Open it to start using Water App.'
                        .tr(namedArgs: {'email': email}),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Look in your spam folder too.'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_note != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            (_noteIsError
                                    ? BrandColors.rose500
                                    : BrandColors.emerald500)
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _note!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: _noteIsError
                              ? BrandColors.rose500
                              : BrandColors.emerald500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _checking ? null : () => _check(),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _checking
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              "I've confirmed it".tr(),
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: (_sending || _wait > 0) ? null : _resend,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        _wait > 0
                            ? 'Resend in {seconds} s'.tr(
                                namedArgs: {'seconds': '$_wait'},
                              )
                            : 'Resend email'.tr(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () => context.read<AuthProvider>().logout(),
                    child: Text('Wrong address? Log out'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
