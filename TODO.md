# TODO

Tracked open items for the Water App mobile / backend pair. Items here
are not blocking the current APK but should be addressed before the
app sees real distribution.

Release-blocking work is tracked separately in
[`DEPLOYMENT.md`](DEPLOYMENT.md); this file is the general backlog.

## Mobile

### History drink icons are guessed from the name
`drink-logs`/dashboard API responses don't include the drink's `slug`,
only `drink_name`/`drink_color`/`icon_path`. `history_screen.dart`'s
`_guessSlug()` pattern-matches on `drink_name` text to pick a `DrinkIcon`
— works for the seeded drinks but breaks for custom or localized names.
Real fix: have the backend include `drink_slug` in those responses
(`DashboardSummaryService`/`DrinkLogController@index`) and read it
directly instead of guessing.

### iOS: launch screen is still the blank placeholder
`ios/Runner/Assets.xcassets/LaunchImage.imageset` holds the three 68-byte
placeholder PNGs from `flutter create`, so the app flashes white before the
first Flutter frame. Android has a themed launch; iOS does not.

### iOS: foreground notification banners untested
Scheduled reminders fire from the OS regardless, but showing a banner while
the app is *in the foreground* depends on `UNUserNotificationCenter`'s
delegate. Verify on a real device before release.

### iOS: permission strings are English-only
`NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription` live in
`Info.plist`, not `assets/i18n`. Translating them means adding
`ios/Runner/<lang>.lproj/InfoPlist.strings` for de/ru/uk and registering
them in the Xcode project.

### Android: no per-app language in system settings
iOS declares its four languages in `CFBundleLocalizations`. The Android
counterpart — `android:localeConfig` pointing at a `locales_config.xml` —
is missing, so the app never appears in Android 13+'s
*Settings → Apps → Language*.

Left out on purpose, because it is not a mechanical add. Locale resolves as
**account locale → in-app picker → device locale**, so a logged-in user
would set the system language and see nothing change. Decide first whether
the OS choice should outrank the account's; the manifest line is the easy
half. Does not affect the store listing — Play reads available languages
from the bundle's resources.

### Type scale exists but most screens still bypass it
`theme.dart`'s `TextTheme` now carries real sizes, per-size tracking and
leading, but ~85 call sites still hardcode `fontSize:` inline — 23 distinct
values between 9 and 130. Only the display-size text and the two smallest
labels were given tracking by hand. The rest is a mechanical pass: replace
each inline `TextStyle(fontSize: n, ...)` with the nearest role plus
`copyWith`. Worth doing per screen, with eyes on the result, rather than in
one sweep — there are no golden tests to catch a regression.

Related: fixed `SizedBox(height: 44)`-style metrics around text will still
break at large system font sizes. `main.dart` clamps text scaling for the
nav bar only.

### `make-icon.ps1` is Windows-only
`System.Drawing` plus a hardcoded `C:\dev\...` output path, so the app icon
cannot be re-rendered on the Mac. Not needed for an iOS build, but there is
no Mac equivalent if the icon ever changes.

### KGP deprecation warning
`shared_preferences_android` and `flutter_timezone` still apply the old
Kotlin Gradle Plugin instead of Flutter's built-in Kotlin. Non-fatal
today; a future Flutter release will refuse to build. Upgrade when their
next majors drop.

### Google / Apple sign-in, and the schema it needs
Not built on either side. The decision is worth making before the first
publish, because the backend schema makes retrofitting it expensive once
real accounts exist — `users.password` is `NOT NULL`, `users.email` is
unique with no linking table, and account deletion validates
`current_password`, so a passwordless user could not delete their own
account. Details and the Apple-specific traps are in the backend's
`RELEASE.md`.

Scope note: Apple requires Sign in with Apple wherever a third-party login
is offered, so this is Google *and* Apple or neither. Facebook is not worth
its compliance overhead here.

### Premium is client-side only so far
`PremiumGate` reads an `entitlement` object the backend does not send yet,
so every account resolves to free. The limits it enforces are UX, not
enforcement — the API will still serve a free user their whole history if
asked directly. See MONETIZATION.md §9 for the server side.

### No store products exist
`UnconfiguredPurchaseService` serves the planned tiers so the paywall can be
laid out, and refuses to transact. Replacing it is one class: implement
`PurchaseService` over `purchases_flutter`, register the three product IDs
in `PremiumProducts`, and pass the real instance to `PaywallScreen`.

The Play half has an ordering constraint worth knowing before you start:
the console only opens the *Monetise* section after a build containing the
billing library has been uploaded to some track, internal testing included.
So it is HTTPS → upload → create products → license testers → test
purchases, and the product IDs cannot be renamed afterwards.

## Backend (water-app)

### Subscriptions table and store webhooks
Blocks everything Premium. Needs a `subscriptions` table, an `entitlement`
object on `/auth/me`, and App Store Server Notifications V2 + Play RTDN so
cancellations, refunds and failed billing actually reach the backend.
Details and field list in MONETIZATION.md §9.

### Add `drink_slug` to log-listing API responses
Needed to fix the "History drink icons are guessed from the name" item
above. `DashboardSummaryService::recentLogsFor()` and
`DrinkLogController@index` both flatten/nest drink data already —
add the slug alongside `drink_name`/`drink_color`.

## Done

- [x] Mobile aligned to backend API field names (volume_ml, hydration_ml, ...)
- [x] Onboarding flow before dashboard
- [x] Backend Tips controller fixed (forLocale scope removed)
- [x] Docker SQLite-readonly fix via named volume at /var/data
- [x] Signed release APK pipeline
- [x] Sky/cyan theme matching web brand
- [x] Light / system / dark theme toggle
- [x] Dashboard searchable drink grid + bottom-sheet picker
- [x] History tab refresh on focus
- [x] Editable profile fields wired to PUT /profile
- [x] Awards screen redesign (badges, hero stats, detail sheet)
- [x] Tips feed redesign (cards with cover images, full-screen reader)
- [x] App icon + name matching web brand ("Water App", sky/cyan droplet)
- [x] Drink icons matching web (`DrinkIcon` mirrors the web's per-slug
      inline SVGs) — replaced the emoji-fallback/`icon_path` approach,
      which assumed the backend serves icon image files (it doesn't;
      `icon_path` is just an emoji character in the database)
- [x] Profile photo / avatar, both sides (`POST`/`DELETE
      /api/v1/profile/avatar`, `image_picker` on the Profile screen)
- [x] Account deletion in-app, password-confirmed — Google Play requires
      it for any app with in-app registration
- [x] Reminders actually fire (local notifications, DST-safe scheduling)
- [x] Whole UI localized; `Accept-Language` sent so backend error and
      validation messages come back translated too
- [x] Cleartext HTTP replaced with per-source-set
      `network_security_config.xml` — permitted in debug/profile, forbidden
      in release, instead of a blanket `usesCleartextTraffic` flag
- [x] Android backup + device-transfer disabled so the bearer token can't
      follow a restored phone
- [x] R8 enabled for release, with keep rules for the notification plugin
- [x] iOS builds and runs — release `Runner.app` + simulator launch verified
      on Xcode 26.5 / Flutter 3.44.1; plugins resolve via Swift Package
      Manager, so there is no `pod install` step
- [x] iOS `Info.plist` given the keys that are not optional: camera and
      photo-library usage descriptions (`image_picker` crashes the process
      without them), `ITSAppUsesNonExemptEncryption`, `CFBundleLocalizations`
- [x] Subscription strategy written against the real feature inventory
      (MONETIZATION.md)
- [x] Entitlement model, offline cache with a 7-day TTL, and `PremiumGate`
      holding the Free/Premium line in one file
- [x] Paywall screen — post-onboarding, contextual sheet, and the standing
      Profile row; close control and Restore covered by tests because they
      are App Review requirements rather than taste
- [x] Second reminder gated, which is the most earned paywall in the app
- [x] Network failures no longer throw out of `ApiService` — every verb
      returns the normal `{success: false, status: 0}` envelope and times out
      at 20 s, so an offline login shows an error instead of a stuck spinner
- [x] Paywall no longer offers Android users Apple Health.
      `PremiumFeature.healthSync` picks Health Connect off-iOS — the one
      string in the app that names a platform, and on a paid screen a wrong
      one is a refund rather than a typo
- [x] Paywall carries the disclosures both stores require on the purchase
      screen itself: auto-renewal terms, and links to Terms and Privacy.
      Lifetime is shown the links without the renewal sentence, because it
      renews nothing. Covered by tests — this is the class of thing that
      gets a build rejected, not a style choice
- [x] An active subscription has a visible way out (Profile → Manage
      subscription, opening the store's own screen). The app cannot cancel
      a store subscription; not offering the route is what generates
      "impossible to cancel" reviews
- [x] Terms and Privacy reachable from Profile → About without going near
      the paywall, plus Help
- [x] Store listing copy for both consoles in all four languages, length
      checked against the console limits (`STORE_LISTING.md`)
- [x] Logging a drink no longer waits on the network. The totals move in the
      same frame as the tap and reconcile behind the user; a failed or
      offline write rolls back whole. Cut three sequential round-trips to
      one, and stopped the first drink of the day blanking the dashboard to
      a spinner
- [x] The progress ring and the daily total animate to their new value
      instead of cutting to it, driven by one tween so they cannot drift
      apart. Reduced motion is honoured through `Motion.of`
- [x] Haptics on the four moments that earn them: drink logged, goal
      reached, purchase confirmed, reminder-interval detent
- [x] `drink_logs.source` reports the real platform — it was hardcoded to
      `android`, which would have mislabelled every log made on an iPhone
- [x] Android release verified on-device after Premium, `image_picker` and
      the `ApiService` rewrite landed: R8 build launches clean, backup flags
      off in the shipped artifact, offline login recovers. The permission
      list in DEPLOYMENT.md now comes from `aapt2 dump badging` on the APK
      rather than from reading the manifest, which understated it
