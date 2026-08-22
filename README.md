# Water App — mobile (Flutter)

Android and iOS client for the
[water-app](https://github.com/vovafes/water-app) Laravel backend.
HydroTrack — daily hydration tracking with onboarding, drink logging,
history, achievements, and per-locale tips.

iOS builds and runs (verified on Xcode 26.5 / Flutter 3.44.1); what it
still needs is an Apple Developer account — see [iOS](#ios) at the bottom.

Going to production? [`DEPLOYMENT.md`](DEPLOYMENT.md) has the release
checklist, the decisions that become irreversible at first publish, and
the list of what is still outstanding.

## What's inside

```
lib/
├── main.dart                Routing: login → onboarding → tabbed home
├── models/                  user, drink, drink_log, achievement
├── providers/               auth_provider, dashboard_provider (Provider/ChangeNotifier)
├── services/api_service.dart  Thin HTTP client over /api/v1
└── screens/
    ├── auth/                login_screen, register_screen
    ├── onboarding/          onboarding_screen (mandatory after first register)
    ├── dashboard/           today's intake + quick-log + recent logs
    ├── diary/               history_screen (grouped by day)
    ├── achievements/        achievements_screen
    ├── tips/                tips_screen (localized JSON-keyed content)
    └── profile/             profile_screen
```

State management is just `package:provider`. Persistence is
`shared_preferences` for the auth token only — the backend is the
source of truth for everything else.

Because that token is the only thing on disk, Android's backup channels
are both switched off (`allowBackup="false"` plus an empty
`res/xml/data_extraction_rules.xml`, which is what covers device-to-device
transfer on API 31+). A restored or transferred phone starts at the login
screen instead of inheriting a bearer token it was never issued.

## Quick start (debug, on an emulator)

```bash
flutter pub get
flutter run --debug
```

Defaults to `API_BASE_URL=http://10.0.2.2:8000`, which is the
Android-emulator-friendly loopback to your machine. Boot the backend
first (`docker compose up -d` in the water-app repo).

## LAN test on a real phone (profile build)

Use this to try the app on your own phone against the dev backend,
before anything goes to a store.

1. **Backend reachable from the phone.** Find your machine's LAN IP
   (`ipconfig` on Windows; on Linux/macOS `ip a` or `ifconfig`), then:

   - Bind the server to every interface, not just loopback:
     ```bash
     php artisan serve --host=0.0.0.0 --port=8000
     ```
   - Set `APP_URL=http://<LAN_IP>:8000` in the backend's `.env` and run
     `php artisan config:clear`. Avatar URLs are built server-side from
     `APP_URL`, so leaving it as `http://localhost` ships the phone a URL
     only your PC can resolve and every profile photo silently 404s.
     (Drink icons and tip covers come from the app's own
     `API_BASE_URL`, so they are unaffected.)
   - Allow inbound TCP 8000 — this needs an **elevated** shell:
     ```powershell
     New-NetFirewallRule -DisplayName "Water App :8000" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
     ```

   Test from the phone's browser: `http://<LAN_IP>:8000/up` should
   answer.

2. **Build and install:**
   ```bash
   flutter build apk --profile --dart-define=API_BASE_URL=http://<LAN_IP>:8000
   adb install -r build/app/outputs/flutter-apk/app-profile.apk
   ```

   That APK is ~100 MB because a profile build is unobfuscated and
   bundles all three ABIs. Add `--target-platform android-arm64` to cut
   it to roughly a third if you're sideloading over the network.

   It has to be `--profile`, not `--release`. Cleartext HTTP is
   permitted only in the debug and profile source sets
   (`android/app/src/{debug,profile}/res/xml/network_security_config.xml`);
   `src/main`, which is what release uses, sets
   `cleartextTrafficPermitted="false"`. A release APK simply cannot
   talk to `http://<LAN_IP>:8000` — every request fails with a cleartext
   error. Point the backend at HTTPS if you need to smoke-test the
   actual release artifact end to end.

## Release APK (store / distribution)

1. **Generate the release keystore** (once):
   ```powershell
   cd android
   .\make-keystore.ps1
   ```
   Prompts for a password. Writes
   `android/app/upload-keystore.jks` and `android/key.properties`
   (both gitignored — back the `.jks` up somewhere safe; losing it
   means you can never sign updates under the same identity).

   To regenerate the app icon (after editing the gradient or droplet):
   ```powershell
   cd android
   .\make-icon.ps1           # renders assets/icon/{icon,icon_foreground}.png
   cd ..
   dart run flutter_launcher_icons
   ```

2. **Build:**
   ```bash
   flutter build apk --release --dart-define=API_BASE_URL=https://<your-host>
   ```
   Output: `build/app/outputs/flutter-apk/app-release.apk` (~60 MB
   universal; add `--target-platform android-arm64` for ~20 MB).
   For Google Play upload `flutter build appbundle` instead — Play
   requires an AAB, not an APK, and splits the ABIs itself so the
   `--target-platform` trick is unnecessary there.

   The host must be HTTPS: release uses
   `src/main/res/xml/network_security_config.xml`, which forbids
   cleartext. Release is also the only build type that runs R8
   (`isMinifyEnabled`/`isShrinkResources`), so anything reflection-based
   needs a keep rule in `android/app/proguard-rules.pro` —
   `flutter_local_notifications`' Gson models are already covered there.

3. **Install on the phone:**
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```
   Or copy the APK over and tap it.

4. **Verify it's signed with the keystore you generated:**
   ```bash
   $env:LOCALAPPDATA\Android\Sdk\build-tools\<v>\apksigner.bat verify --print-certs build\app\outputs\flutter-apk\app-release.apk
   ```

## Backend dialect

This project is wired directly to the backend's actual JSON shapes —
field names like `volume_ml`, `hydration_ml`, `consumed_at`,
`hydration_multiplier`, `default_volumes`, `icon_path`. Earlier
prototypes used different names (`amount`, `water_equivalent`,
`logged_at`, `hydration_coefficient`, `default_amount`) — those are
gone. The dashboard endpoint already returns popular drinks, so there's
no separate `/drinks/popular` call from the app.

`POST /drink-logs` sends `{drink_id, volume_ml, source: "android"}`.
The list endpoint returns Laravel's paginate envelope; we read
`body.data`.

Every request carries `Accept-Language`, kept in sync with the app
locale by `main.dart`. The backend's `SetLocale` middleware runs on the
API group and prefers the *account's* stored locale, falling back to
that header — so error text ("Неверный пароль.", validation messages)
comes back in the user's language instead of English. Strings the
mobile app never authors can't be translated client-side, which is why
this matters.

## Onboarding requirement

The backend won't compute `target_ml` until the user has POSTed to
`/profile/onboarding` with sex, birth date, weight, height, activity,
climate, sleep, and goal. `main.dart` enforces this — if
`auth.user.onboardedAt` is null, the app routes to `OnboardingScreen`
before the dashboard.

## Toolchain

| Tool | Version |
|---|---|
| Flutter | 3.44.1 stable |
| Dart | 3.12.1 (constraint `^3.12.1` in pubspec) |
| Java | Temurin JDK 17 |
| Gradle | 8.x (wrapper-managed) |
| Android compileSdk | 36 |
| Min SDK | whatever `flutter` resolves (currently 24) |
| Kotlin JVM target | 17 |
| Core library desugaring | enabled (required by `flutter_local_notifications`) |
| Xcode | 26.5 (17F42) |
| iOS deployment target | 13.0 |
| iOS plugin manager | Swift Package Manager — no Podfile |

Run `flutter doctor` to verify. Visual Studio is *not* required —
that warning is for Windows desktop builds, which this project does
not produce.

## Known limitations

Tracked with the rest of the release work in [`DEPLOYMENT.md`](DEPLOYMENT.md).

1. **Release needs an HTTPS backend.** Cleartext is allowed only in
   the debug and profile source sets; release forbids it. There is no
   `usesCleartextTraffic` flag in the manifest to flip — the switch is
   the per-source-set `network_security_config.xml`, and it is
   deliberately strict for the artifact that ships.
2. **The privacy policy exists but is not publicly reachable.** The
   backend serves `/privacy`, `/terms` and `/help`, and the policy names
   the health data the app collects (birth date, weight, height), which
   drives the stricter Data Safety declaration. Play needs a public URL
   though, so this stays blocked behind item 1. The page bodies are also
   English-only for now.
3. **Password reset silently does nothing in production.** The backend's
   `.env` still has `MAIL_MAILER=log`, so `POST /auth/forgot-password`
   returns 200 and writes the mail to `storage/logs`. Point it at a real
   transport before release.
4. **Version is `1.0.0+1`.** Correct for the *first* upload — nothing has
   shipped yet, and there are no tags. Bump `version:` in `pubspec.yaml`
   before every upload after that; Play rejects a `versionCode` it has
   already seen.
5. **`applicationId` is `com.vovafes.water_app_mobile`.** Permanent from
   the first publish onwards — changing it later means a new listing with
   no install base. Worth a second look before the first upload.
6. **Kotlin Gradle Plugin deprecation warning** — `shared_preferences_android`
   and `flutter_timezone` still apply KGP instead of Flutter's built-in
   Kotlin. Non-fatal today, but future Flutter releases will refuse to
   build. Upgrade when their next majors drop.
7. **Drink icons are guessed from the display name.** The dashboard and
   `drink-logs` responses carry `drink_name`/`drink_color`/`icon_path`
   but no `slug`, so `_guessSlug()` pattern-matches on the name text to
   pick an icon. That breaks for custom drinks and for any localized
   name; the real fix is adding `drink_slug` to those responses on the
   backend.

## iOS

Builds and runs. Verified on macOS 26.5 with Xcode 26.5 and Flutter
3.44.1: `flutter analyze` clean, 34 tests green, a 20.7 MB
`Runner.app` from `--release --no-codesign`, and a simulator launch that
reaches the login screen.

```bash
flutter build ipa --release --dart-define=API_BASE_URL=https://<host>
```

There is **no `pod install` step**. Flutter 3.44 resolves the four iOS
plugins through Swift Package Manager, so no `ios/Podfile` is generated
and `flutter doctor`'s CocoaPods warning is a red herring. (CocoaPods is
still worth having on the build Mac — Flutter falls back to it for any
plugin added later that lacks SPM support.)

Two more corrections to what earlier notes said:

- **Do not add an ATS cleartext exception.** App Transport Security's
  HTTPS-only default is exactly the posture the Android release build has.
  Point the app at an HTTPS backend instead.
- **No push-notification capability is needed.** Reminders are *local*
  notifications; the permission is requested at runtime and no APNs
  entitlement is involved.

`AppIcon.appiconset` already carries the branded droplet — the
`flutter_launcher_icons` config has `ios: true` and has been run.

What is left is account-side, not code: an Apple Developer membership
($99/yr), a registered bundle ID (`com.vovafes.waterAppMobile` — note it
differs from Android's `com.vovafes.water_app_mobile`, since iOS bundle
IDs cannot contain underscores), and a `DEVELOPMENT_TEAM` selected in
Xcode. [`DEPLOYMENT.md`](DEPLOYMENT.md) has the full submission checklist
and the remaining gaps.

## License

Proprietary — all rights reserved. See [LICENSE](LICENSE).
