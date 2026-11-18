import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Shown while a saved session is being checked with the server, and when
/// that check could not reach it.
///
/// Until now the app showed the sign-in form for the whole time /auth/me was
/// in flight, so someone who was already signed in saw the login screen on
/// every cold start (for as long as the network took), and on a bad
/// connection stayed on it and signed in a second time for nothing.
class SessionSplash extends StatelessWidget {
  /// True when the server could not be reached; offers a retry instead of a
  /// spinner.
  final bool failed;
  final VoidCallback onRetry;

  const SessionSplash({super.key, required this.failed, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The real app icon, as on the sign-in screen.
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 76,
                  height: 76,
                ),
              ),
              const SizedBox(height: 28),
              if (failed) ...[
                Text(
                  'No connection to the server'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: Text('Try again'.tr())),
              ] else
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
