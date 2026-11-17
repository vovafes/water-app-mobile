# Preview

What the app looks like on a phone. The website has its own tour in the
backend repo's [`PREVIEW.md`](https://github.com/vovafes/water-app/blob/main/PREVIEW.md).

Screenshots below are from the **Android** build (Pixel 10 emulator,
Android API 37, 1080×2424), English locale, logged in as the seeded demo
account against a local backend. Light theme first, then dark.

**iOS is not shown here.** The iOS simulator only runs on macOS, and these
shots were taken on Windows. The screens are one Flutter codebase, so the
layouts are the same on iPhone. What differs is system chrome: the status
bar and home indicator, the back-swipe gesture, and the launch screen
(white droplet on brand blue, see `ios/Runner/Base.lproj/LaunchScreen.storyboard`).
To add iPhone shots, run the app in the simulator on the Mac and drop the
PNGs into `docs/preview/ios/`.

---

## Sign in

<img src="docs/preview/01-login.png" width="260" alt="Sign in">

## Home

Today's progress at the top, then every drink as one tap. Tapping the
streak chip opens the streak calendar.

<img src="docs/preview/02-dashboard.png" width="260" alt="Dashboard"> <img src="docs/preview/03-log-a-drink.png" width="260" alt="Log a drink"> <img src="docs/preview/04-streak.png" width="260" alt="Streak">

## History, achievements, tips

Swipe an entry left in History to delete it (it asks first).

<img src="docs/preview/05-history.png" width="260" alt="History"> <img src="docs/preview/06-achievements.png" width="260" alt="Achievements"> <img src="docs/preview/07-tips.png" width="260" alt="Tips">

## Profile, Premium, reminders

<img src="docs/preview/08-profile.png" width="260" alt="Profile"> <img src="docs/preview/09-premium.png" width="260" alt="Premium paywall"> <img src="docs/preview/10-reminders.png" width="260" alt="Reminders">

## Dark theme

Follows the system setting by default; the Profile tab has a manual
light / system / dark switch.

<img src="docs/preview/11-dashboard-dark.png" width="260" alt="Dashboard, dark"> <img src="docs/preview/12-achievements-dark.png" width="260" alt="Achievements, dark">

---

*Screenshots are not auto-generated. Retake them after any visual change.*
