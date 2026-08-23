import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';

/// The URLs a paid screen is required to reach.
///
/// The legal pages follow `API_BASE_URL` rather than a hardcoded domain,
/// because the domain does not exist yet and a link to the wrong host is
/// worse than one that moves with the build.
class LegalUrls {
  const LegalUrls._();

  static Uri get privacy => Uri.parse('${ApiService.siteUrl}/privacy');
  static Uri get terms => Uri.parse('${ApiService.siteUrl}/terms');

  /// Where a subscriber actually cancels.
  ///
  /// Neither store lets an app cancel its own subscription — the app can
  /// only send the user to the store's screen. Shipping no route at all is
  /// what generates one-star "impossible to cancel" reviews, and both
  /// review teams look for it.
  static Uri get manageSubscription =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? Uri.parse('https://apps.apple.com/account/subscriptions')
      : Uri.parse('https://play.google.com/store/account/subscriptions');
}

/// Opens [url] outside the app.
///
/// Returns false when nothing could handle it — on a device with no
/// browser, or when the backend host is unreachable. Callers show their own
/// message rather than failing silently, because a dead legal link on a
/// paywall is a rejection.
Future<bool> openExternal(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Renewal terms plus the two links, as both stores require them.
///
/// Apple's 3.1.2 and Play's subscription policy both want the same things
/// visible *on the purchase screen*, not buried in settings: what is being
/// bought, for how long, at what price, that it renews by itself, and a
/// route to the Terms and the Privacy Policy. Price, duration and trial
/// terms are on the plan rows above this; this widget carries the rest.
///
/// Deliberately at [TextTheme.bodySmall] rather than shrunk to 8pt. Fine
/// print small enough to be unreadable is the exact pattern reviewers open
/// the guideline for.
class LegalFooter extends StatelessWidget {
  /// Whether to state the auto-renewal terms. False for the lifetime
  /// product, which is a one-off purchase and renews nothing — claiming
  /// otherwise there would be a false statement on a paid screen.
  final bool renewing;

  const LegalFooter({super.key, required this.renewing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (renewing)
          Text(
            'Subscription renews automatically unless cancelled at least 24 hours before the period ends. Manage it in your store account.'
                .tr(),
            style: muted,
            textAlign: TextAlign.center,
          ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _LegalLink(label: 'Terms of Use'.tr(), url: LegalUrls.terms),
            Text('·', style: muted),
            _LegalLink(label: 'Privacy Policy'.tr(), url: LegalUrls.privacy),
          ],
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final Uri url;

  const _LegalLink({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextButton(
      onPressed: () async {
        final ok = await openExternal(url);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open the page'.tr())),
          );
        }
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          decoration: TextDecoration.underline,
          decorationColor: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
