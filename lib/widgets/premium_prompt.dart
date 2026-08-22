import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../premium/premium_gate.dart';
import '../screens/paywall/paywall_screen.dart';
import '../theme.dart';

/// The short paywall shown when a free user reaches a locked feature.
///
/// Deliberately a bottom sheet and not the full screen. The user was in the
/// middle of doing something — tapping a drink, adding a reminder — and a
/// full takeover loses their place and reads as a punishment. The sheet
/// names the thing they reached for, offers it, and gets out of the way.
///
/// Returns true if the user came back holding Premium.
Future<bool> showPremiumPrompt(
  BuildContext context,
  PremiumFeature feature, {
  required String source,
}) async {
  final bought = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _PremiumPromptSheet(feature: feature, source: source),
  );
  return bought == true;
}

class _PremiumPromptSheet extends StatelessWidget {
  final PremiumFeature feature;
  final String source;

  const _PremiumPromptSheet({required this.feature, required this.source});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [BrandColors.gradientStart, BrandColors.gradientEnd],
              ),
            ),
            child: const Icon(Icons.workspace_premium, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            feature.prompt,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            feature.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                // The sheet hands off to the full screen rather than trying
                // to sell from inside a sheet: plan choice, trial timeline
                // and the legal row do not fit here, and shipping them
                // half-size is how paywalls get rejected.
                final bought = await navigator.push<bool>(
                  MaterialPageRoute(
                    builder: (_) => PaywallScreen(source: source),
                    fullscreenDialog: true,
                  ),
                );
                navigator.pop(bought == true);
              },
              child: Text(feature.cta),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Not now'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
