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

### iOS build
`ios/` exists but is unbuilt. See README for what a Mac-side build
requires.

### KGP deprecation warning
`shared_preferences_android` and `flutter_timezone` still apply the old
Kotlin Gradle Plugin instead of Flutter's built-in Kotlin. Non-fatal
today; a future Flutter release will refuse to build. Upgrade when their
next majors drop.

## Backend (water-app)

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
