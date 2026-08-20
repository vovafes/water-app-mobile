# Deployment — Android

The release checklist for the Flutter client, and what is still
outstanding. Build commands live in [`README.md`](README.md); this file is
about what has to be *decided* and *verified*.

The backend has its own list in
[water-app/RELEASE.md](https://github.com/vovafes/water-app/blob/main/RELEASE.md) —
several items there block this one.

Checked against the working tree on 2026-08-20.

## Build types are not interchangeable

| | debug | profile | release |
|---|---|---|---|
| Cleartext HTTP | allowed | allowed | **forbidden** |
| R8 / resource shrinking | no | no | yes |
| Signing | debug key | debug key | `upload-keystore.jks` |
| Network config source set | `src/debug` | `src/profile` | `src/main` |

The cleartext row is the one that surprises people. `src/main` sets
`cleartextTrafficPermitted="false"`, and there is no `usesCleartextTraffic`
manifest flag to flip — the switch *is* the per-source-set
`network_security_config.xml`. A release build pointed at
`http://<LAN_IP>:8000` fails every single request. That is why LAN testing
uses `--profile`, and why the backend must be HTTPS before a release build
can be smoke-tested end to end.

## Signing

`android/app/upload-keystore.jks` and `android/key.properties` are both
gitignored, generated once by `android/make-keystore.ps1`.

**Back the `.jks` up somewhere that survives this machine dying.** Losing it
means you can never publish an update to the same listing — Play identifies
the app by signing key, and the only escape is enrolling in Play App Signing
*before* you lose it, or starting a new listing with zero installs.

`build.gradle.kts` falls back to the debug key when `key.properties` is
absent, so `flutter build apk --release` on a fresh clone silently produces
an unpublishable artifact. Verify what you actually built:

```powershell
$env:LOCALAPPDATA\Android\Sdk\build-tools\<v>\apksigner.bat verify --print-certs `
  build\app\outputs\flutter-apk\app-release.apk
```

## One-way decisions — settle these before the first upload

### `applicationId`

Currently `com.vovafes.water_app_mobile`. Permanent from the moment the
first artifact reaches Play. Changing it later is not a rename; it is a new
listing with no reviews, no ratings and no install base. The `_mobile`
suffix is a repo-name artifact rather than a product decision, so it is
worth one deliberate look now.

### App name

`res/values/strings.xml` holds `app_name` = "Water App". Deliberately not
localized into `values-de/-ru/-uk`:

- "Water App" is the brand, and it renders untranslated everywhere else in
  the app (the login header, `MaterialApp.title`).
- Android resolves this string against the **system** locale, not the
  in-app one from `easy_localization`. A translated launcher label would
  disagree with the UI the moment a user runs the app in a language other
  than their phone's.

Note that `README.md` calls the product "HydroTrack" while the app calls
itself "Water App". Pick one.

### Version

`pubspec.yaml` is at `1.0.0+1`. That is **correct for the first upload** —
nothing has shipped, and the repo has no tags. From the second upload
onward, bump `version:` every time; Play rejects a `versionCode` it has
already seen. The `+N` suffix is the versionCode.

## Play submission checklist

- [ ] **AAB, not APK.** `flutter build appbundle --release --dart-define=API_BASE_URL=https://<host>`.
      Play requires a bundle and splits the ABIs itself, so `--target-platform`
      is unnecessary there.
- [ ] **Privacy policy URL.** The page itself exists and is written
      (`/privacy` on the backend, and it names the health data — birth date,
      weight, height — that forces the stricter declaration below). What is
      missing is a public host to serve it from, so this reduces to the
      HTTPS item. Note the body is English-only today; the backend list
      tracks whether to translate it.
- [ ] **Data Safety form.** Declare: email + name (account), health/fitness
      (onboarding measurements), photos (avatar), app activity (drink logs).
      All linked to the account, all deletable.
- [ ] **Account deletion.** Already implemented in-app (Profile → Delete
      account, `DELETE /api/v1/profile/account`) and on the web profile page.
      Play asks for a web-reachable deletion URL too — the web profile page
      covers it once the site is public.
- [ ] **Target API level.** Currently 36, min 24. Play's floor moves every
      August; re-check before submitting.
- [ ] **Permissions.** Only `INTERNET`, `POST_NOTIFICATIONS` and
      `RECEIVE_BOOT_COMPLETED`. Reminder scheduling is inexact on purpose,
      so there is **no** exact-alarm permission and therefore no policy
      declaration to fill in. Keep it that way — switching to exact alarms
      would add a review step.

## Data on the device

`shared_preferences` holds the Sanctum bearer token and the theme/locale
preferences. Nothing else is persisted locally; the backend is the source
of truth.

Both Android backup channels are therefore switched off:

- `android:allowBackup="false"` — kills Google's cloud backup.
- `res/xml/data_extraction_rules.xml` with empty `<cloud-backup>` and
  `<device-transfer>` — on API 31+, `allowBackup="false"` does **not** stop
  device-to-device transfer; only this file does.

Without both, a restored or transferred phone inherits a bearer token that
was issued to different hardware. Verify on a device:

```bash
adb shell dumpsys package com.vovafes.water_app_mobile | grep pkgFlags
# expected: pkgFlags=[ HAS_CODE ALLOW_CLEAR_USER_DATA ]  — no ALLOW_BACKUP
```

## Verification before publishing

```bash
flutter analyze                # must be clean
flutter test                   # 34 tests
```

Then build the release artifact and actually launch it. R8 only runs in
release, so reflection-based failures appear nowhere else:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://<host>
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb logcat -c && adb shell am start -n com.vovafes.water_app_mobile/.MainActivity
adb logcat -d -b crash -t 100
```

`android/app/proguard-rules.pro` already keeps
`flutter_local_notifications`' Gson models. Anything else added later that
relies on reflection needs its own keep rule, and the only way to find out
is this launch test.

**Watch the ABI when sideloading.** `--target-platform android-arm64` cuts
the APK from ~60 MB to ~20 MB, but the resulting artifact will not start on
an x86_64 emulator — it dies with
`libflutter.so is for EM_AARCH64 (183) instead of EM_X86_64 (62)`. That is
the build, not a bug. Emulator smoke tests need a universal build or
`--target-platform android-x64`.

## Still to do

Ordered by what blocks what.

1. **Backend on HTTPS** — nothing release-shaped can be tested until then,
   and it is also what makes the privacy policy publicly reachable, which
   is a hard Play blocker. One item, two gates.
2. **Real mail transport on the backend** — `forgot-password` is wired up in
   the app and currently does nothing in production.
3. **Confirm `applicationId` and the app name** — both are effectively
   irreversible after the first publish.
4. **KGP deprecation** — `shared_preferences_android` and `flutter_timezone`
   still apply the Kotlin Gradle Plugin instead of Flutter's built-in
   Kotlin. Non-fatal today; a future Flutter release will refuse to build.
   Upgrade when their next majors drop.
5. **iOS is unbuilt.** `ios/` exists from `flutter create` and has never
   been compiled. Needs a Mac, an Apple Developer account, cleartext/ATS
   handling in `Info.plist`, a notification capability, and a real app icon.
