# Water App — mobile (Flutter)

Android client for the
[water-app](https://github.com/vovafes/water-app) Laravel backend.
HydroTrack — daily hydration tracking with onboarding, drink logging,
history, achievements, and per-locale tips.

iOS is partially scaffolded (`ios/` directory exists from
`flutter create`) but unbuilt — see the bottom of this file.

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

## Quick start (debug, on an emulator)

```bash
flutter pub get
flutter run --debug
```

Defaults to `API_BASE_URL=http://10.0.2.2:8000`, which is the
Android-emulator-friendly loopback to your machine. Boot the backend
first (`docker compose up -d` in the water-app repo).

## Release APK (real phone, same Wi-Fi)

1. **Backend reachable from the phone.** Find your machine's LAN IP
   (`ipconfig` on Windows; on Linux/macOS `ip a` or `ifconfig`).
   Make sure inbound TCP 8000 is allowed:
   ```powershell
   New-NetFirewallRule -DisplayName "Water App :8000" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
   ```
   Test from the phone's browser: `http://<LAN_IP>:8000/up` should
   answer.

2. **Generate the release keystore** (once):
   ```powershell
   cd android
   .\make-keystore.ps1
   ```
   Prompts for a password. Writes
   `android/app/upload-keystore.jks` and `android/key.properties`
   (both gitignored — back the `.jks` up somewhere safe; losing it
   means you can never sign updates under the same identity).

3. **Build:**
   ```bash
   flutter build apk --release --dart-define=API_BASE_URL=http://<LAN_IP>:8000
   ```
   Output: `build/app/outputs/flutter-apk/app-release.apk` (~53 MB).

4. **Install on the phone:**
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```
   Or copy the APK over and tap it.

5. **Verify it's signed with the keystore you generated:**
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
| Min SDK | whatever `flutter` resolves (currently 21) |
| Kotlin JVM target | 17 |
| Core library desugaring | enabled (required by `flutter_local_notifications`) |

Run `flutter doctor` to verify. Visual Studio is *not* required —
that warning is for Windows desktop builds, which this project does
not produce.

## Known limitations

1. **Cleartext HTTP only.** The AndroidManifest has
   `android:usesCleartextTraffic="true"` because the dev backend is
   plain HTTP. Switch the backend to HTTPS and drop the flag before
   any real distribution.
2. **No icon images for drinks yet.** The backend returns
   `icon_path` for each drink (relative to `/storage`) but the mobile
   chip currently renders an emoji keyed off the category slug.
   `Drink.iconUrl` is already plumbed — wire it to a `NetworkImage`
   when the backend's `storage:link` is in place.
3. **`/api/v1/tips` 500s** because the backend's `TipArticleController`
   calls a query scope (`forLocale`) that the `TipArticle` model
   doesn't have. The mobile Tips tab shows an empty state instead of
   crashing — but to actually display tips, drop the `->forLocale($locale)`
   call from the controller (the JSON is locale-keyed already and the
   client resolves the right language at read time).
4. **`shared_preferences_android` deprecation warning** — uses the
   old Kotlin Gradle Plugin. Non-fatal, but future Flutter releases
   will reject it. Upgrade when its next major drops.

## iOS

`ios/` exists but has not been built. iOS builds require a Mac
(Xcode is macOS-only) and an Apple Developer account ($99/yr) for
distribution. On a Mac:

```bash
cd ios && pod install && cd ..
flutter build ipa --release --dart-define=API_BASE_URL=https://<host>
```

Before that works, you need to:
- Edit `ios/Runner/Info.plist` to allow cleartext (or use HTTPS).
- Add notification capability + permission request for
  `flutter_local_notifications`.
- Replace the default `AppIcon.appiconset`.

## License

MIT.
