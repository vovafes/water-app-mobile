import 'package:easy_localization/easy_localization.dart';
import '../models/entitlement.dart';

/// Everything the free tier is allowed to do, in one place.
///
/// The numbers here are the Free/Premium line from MONETIZATION.md §3.
/// They are deliberately not scattered across the screens that enforce
/// them: this is the file to open when the line moves, and moving it is a
/// product decision, not a UI one.
///
/// These limits are **UX, not enforcement.** The backend is the source of
/// truth for logs, drinks and reminders, so a determined user can still
/// call the API directly. Server-side checks land with the `subscriptions`
/// table (MONETIZATION.md §9); until then this is a fence, not a wall, and
/// that is an accepted trade for the first release.
class FreeLimits {
  const FreeLimits._();

  /// History beyond this is blurred behind a paywall prompt. Chosen so the
  /// wall is met in week two — once the habit exists and the streak is
  /// worth keeping.
  static const historyDays = 7;

  /// One schedule is enough to be useful; the second is the most "earned"
  /// paywall in the app, because the user is already using the feature.
  static const reminders = 1;

  /// Water, tea and coffee cover the overwhelming majority of logging.
  /// Everything else — juice, alcohol, custom drinks — is Premium. Note
  /// this gates the *catalogue*, never the hydration multiplier itself:
  /// a free user's coffee still counts at its real coefficient.
  static const drinkSlugs = {'water', 'tea', 'coffee'};

  /// Badges past this stay visible but locked. The locked ones are the
  /// advertisement.
  static const achievements = 3;

  /// Tips per rolling week.
  static const tipsPerWeek = 3;
}

/// A thing the user just tried to do that Premium would allow.
///
/// Each case maps to one contextual paywall. The copy differs per feature
/// on purpose — "Открыть все напитки" converts better than a generic
/// "Оформить Premium", because it names what the user was reaching for.
enum PremiumFeature {
  adaptiveTarget,
  fullDrinkLibrary,
  moreReminders,
  fullHistory,
  streakInsights,
  allAchievements,
  allTips,
  csvExport,
  healthSync;

  /// Headline for the contextual prompt.
  ///
  /// Translated here rather than at the call site: an untranslated key
  /// handed to a widget renders English in every locale, and the i18n test
  /// can only catch that when `.tr()` sits on the literal itself.
  String get prompt => switch (this) {
    PremiumFeature.adaptiveTarget => 'Let your goal follow the weather'.tr(),
    PremiumFeature.fullDrinkLibrary => 'Unlock every drink'.tr(),
    PremiumFeature.moreReminders => 'Add more reminder schedules'.tr(),
    PremiumFeature.fullHistory => 'See your whole history'.tr(),
    PremiumFeature.streakInsights => 'See how your streaks really run'.tr(),
    PremiumFeature.allAchievements => 'Unlock every badge'.tr(),
    PremiumFeature.allTips => 'Read the full tips library'.tr(),
    PremiumFeature.csvExport => 'Export your data'.tr(),
    PremiumFeature.healthSync => 'Sync with Apple Health'.tr(),
  };

  String get body => switch (this) {
    PremiumFeature.adaptiveTarget =>
      'Heat, training and a short night all change how much you need. Premium recalculates your goal every morning.'
          .tr(),
    PremiumFeature.fullDrinkLibrary =>
      'Juice, soda, beer and anything you add yourself — each counted at its real hydration coefficient.'
          .tr(),
    PremiumFeature.moreReminders =>
      'Different schedules for weekdays and weekends, with quiet hours that actually stay quiet.'
          .tr(),
    PremiumFeature.fullHistory =>
      'The free plan remembers a week. Premium keeps every day, every drink, every slip.'
          .tr(),
    PremiumFeature.streakInsights =>
      'Trends over months, and a streak freeze for the day life gets in the way.'
          .tr(),
    PremiumFeature.allAchievements =>
      'Every badge in the app, including the long ones worth chasing.'.tr(),
    PremiumFeature.allTips =>
      'The whole library, in your language, without a weekly limit.'.tr(),
    PremiumFeature.csvExport =>
      'Every log you have ever made, as a spreadsheet you own.'.tr(),
    PremiumFeature.healthSync =>
      'Your water intake, where the rest of your health data already lives.'
          .tr(),
  };

  /// Button label. Phrased as the thing that happens, never as the tariff.
  String get cta => switch (this) {
    PremiumFeature.fullDrinkLibrary => 'Unlock all drinks'.tr(),
    PremiumFeature.moreReminders => 'Unlock reminders'.tr(),
    PremiumFeature.fullHistory => 'Unlock full history'.tr(),
    _ => 'See what Premium adds'.tr(),
  };
}

/// Reads an [Entitlement] and answers "may they?".
///
/// Deliberately a plain function over the entitlement rather than a
/// provider: the answer must be identical everywhere, and a widget that
/// forgets to listen should still get the right result.
class PremiumGate {
  final Entitlement entitlement;

  const PremiumGate(this.entitlement);

  bool get isPremium => entitlement.isActive;

  bool allows(PremiumFeature _) => isPremium;

  /// How many days of history to show. Premium gets everything.
  int? get historyDayLimit => isPremium ? null : FreeLimits.historyDays;

  int? get reminderLimit => isPremium ? null : FreeLimits.reminders;

  bool allowsDrink(String? slug) {
    if (isPremium) return true;
    // An unknown slug is treated as free rather than locked. The backend
    // does not send `drink_slug` on log listings yet (see TODO.md), so
    // failing closed here would lock drinks the user can already log.
    if (slug == null) return true;
    return FreeLimits.drinkSlugs.contains(slug);
  }

  bool allowsAchievementAt(int index) =>
      isPremium || index < FreeLimits.achievements;
}
