# Deployment — Android

The release checklist for the Flutter client, and what is still
outstanding. Build commands live in [`README.md`](README.md); this file is
about what has to be *decided* and *verified*.

The backend has its own list in
[water-app/RELEASE.md](https://github.com/vovafes/water-app/blob/main/RELEASE.md) —
several items there block this one.

Checked against the working tree on 2026-08-24, after Premium, `image_picker`,
the `ApiService` rewrite and the optimistic-write/motion pass landed. Anything
below marked *verified* was run on a device on the date given beside it, not
read off the source — the two dates differ, and the gap is listed under
[Not yet seen on a device](#not-yet-seen-on-a-device).

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
- [ ] **Store listing copy.** Written and length-checked for both consoles
      in all four languages: [`STORE_LISTING.md`](STORE_LISTING.md). Paste
      from there rather than retyping — several fields sit within a few
      characters of the limit, and `python tool/check_store_listing.py`
      re-validates after any edit (24 fields, exits non-zero on a problem).
      It also catches U+FFFD replacement characters, which is how two
      corrupted Ukrainian words once survived a read-through. Screenshots
      are **not** done and cannot
      be written: they need a populated account, shot per language, plus a
      1024×500 feature graphic for Play.
- [ ] **Data Safety form.** Declare: email + name (account), health/fitness
      (onboarding measurements), photos (avatar), app activity (drink logs).
      All linked to the account, all deletable. Once billing is wired,
      **purchase history** joins the list — Play treats it as *Financial
      info*, and it is collected even though the app never sees a card
      number, because the entitlement is stored against the account.
- [ ] **Subscription products.** Not creatable yet, and the ordering is not
      obvious: Play only offers the *Monetise* section once a build
      containing the billing library has been uploaded to **some** track,
      internal testing included. So the sequence is
      *HTTPS host → upload a build with billing → create the three products
      from `PremiumProducts` → add license testers → test purchases*.
      Trying to register the IDs first fails with an unhelpful error.

      Keep annual and monthly in **one subscription group**; outside a
      group, upgrade/downgrade does not work and a user can end up holding
      two active subscriptions. Lifetime is a non-consumable and sits
      outside by definition. The IDs are already fixed in
      `lib/services/purchase_service.dart` and must be typed into the
      console identically — a product ID cannot be renamed or reused after
      creation.
- [ ] **Account deletion.** Already implemented in-app (Profile → Delete
      account, `DELETE /api/v1/profile/account`) and on the web profile page.
      Play asks for a web-reachable deletion URL too — the web profile page
      covers it once the site is public.
- [ ] **Target API level.** Currently 36, min 24. Play's floor moves every
      August; re-check before submitting.
- [ ] **Permissions.** What the *built APK* declares, which is not the same
      as what `AndroidManifest.xml` lists — plugins merge their own in:

      | Permission | Source |
      |---|---|
      | `INTERNET` | ours |
      | `POST_NOTIFICATIONS` | ours |
      | `RECEIVE_BOOT_COMPLETED` | ours |
      | `VIBRATE` | `flutter_local_notifications` |
      | `<applicationId>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX |

      The last is signature-level and generated per package; it grants
      nothing to anyone else and needs no declaration. `VIBRATE` is not
      dangerous and needs no runtime prompt, but it *is* visible on the
      store listing, so do not be surprised by it.

      Notably **absent**: `image_picker` adds no permission at all. It
      contributes a `FileProvider` and a Play-services module hook for the
      backported photo picker, but takes the photo through an intent, so
      there is no `CAMERA` or storage permission and nothing to justify on
      the Data Safety form beyond the avatar itself.

      Reminder scheduling is inexact on purpose, so there is **no**
      exact-alarm permission and therefore no policy declaration to fill
      in. Keep it that way — switching to exact alarms would add a review
      step.

      The haptics added alongside the drink-logging rework add **no**
      permission either. `HapticFeedback` goes through the view's
      `performHapticFeedback`, not the vibrator service, so it needs
      nothing declared. The `VIBRATE` line above is still
      `flutter_local_notifications`' and would be there regardless.

      Re-run this check after adding any plugin:
      ```bash
      aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk | grep uses-permission
      ```

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
flutter test                   # 63 tests
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

If `adb install` fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, a
profile or debug build is already installed — those are signed with the
debug key and the release one is not. `adb uninstall` first; `-r` cannot
cross a signing-key change.

### Last verified

Run on 2026-08-23 against `Pixel_10` (API 36 emulator), after Premium,
`image_picker` and the `ApiService` rewrite landed:

| Check | Result |
|---|---|
| `flutter analyze` | clean |
| `flutter test` | 50 passed |
| `flutter build apk --release` | 57.8 MB universal, R8 on |
| Launch under R8 | login screen renders, no fatals in `-b crash` |
| `pkgFlags` | `[ HAS_CODE ALLOW_CLEAR_USER_DATA ]` — no `ALLOW_BACKUP` |
| Offline login | "No connection to the server", button re-enabled |

This table is a record of one run, not a running total — leave the numbers
alone when they go stale. The suite is 63 tests as of 2026-08-24; the 50
above is what it was on the day the APK in the row below it was built.

The offline row is the one worth repeating by hand. The APK was built
against a deliberately unresolvable host, and before `_send()` existed a
transport failure threw straight out of `AuthProvider.login()`, skipping
`_loading = false` — the button spun forever with no error and no way back.
That path is Android-identical to iOS but had only ever been checked on
iOS.

**Not yet seen on a device.** Three things landed after that run and have
only ever been exercised in the test suite.

*The paywall's legal block* — renewal terms plus the Terms and Privacy
links. A widget test lays the screen out at 360×640 and fails on a
`RenderFlex` overflow, so it fits; but the links have never been *tapped*
on hardware, and they cannot be until the backend is on a reachable host.
Add both taps to the next on-device pass: a reviewer follows them by hand,
and a dead legal link on a paid screen is a rejection.

*The optimistic drink write.* The totals now move in the same frame as the
tap and the request settles behind the user. The happy path is the easy
half — the one to actually check is the failure: point the build at an
unreachable host, or stop the backend mid-session, and log a glass. The
ring and the number must jump forward, then roll back whole, with an error
snackbar. This is a *new* visible state; before the rework a failed write
simply never moved anything. Nine tests in
`test/dashboard_optimistic_test.dart` cover the arithmetic and the
rollback, but nothing covers how it looks.

*The motion and the haptics.* The progress ring and the daily total animate
to their new value over 650 ms and honour reduced motion; four moments
buzz — drink logged, goal reached, purchase confirmed, reminder-interval
detent. Neither can be judged from a test. On the device, check three
things: that logging two drinks in quick succession makes the second count
continue from the number on screen instead of jumping back, that the goal
haptic fires on the crossing rather than a beat late, and that
*Settings → Accessibility → Remove animations* leaves the totals correct
while stilling the motion.

**Watch the ABI when sideloading.** `--target-platform android-arm64` cuts
the APK from ~60 MB to ~20 MB, but the resulting artifact will not start on
an x86_64 emulator — it dies with
`libflutter.so is for EM_AARCH64 (183) instead of EM_X86_64 (62)`. That is
the build, not a bug. Emulator smoke tests need a universal build or
`--target-platform android-x64`.

## Known Android-side gaps

1. **No `android:localeConfig`.** iOS declares its four languages in
   `CFBundleLocalizations`; the Android counterpart is a `locales_config.xml`
   that puts the app in Android 13+'s *Settings → Apps → Language* picker.
   It is deliberately absent, not forgotten. Locale resolves as **account
   locale → in-app picker → device locale**, so for a logged-in user the
   system picker would appear and then silently do nothing, which is worse
   than not offering it. Adding it means first deciding whether the OS
   choice outranks the account's — a product decision, not a manifest line.
   Note this does not affect the store listing: Play reads the available
   languages from the bundle's resources either way.
2. **Billing is a stub.** `UnconfiguredPurchaseService` returns
   `PurchaseResult.unavailable` for every product, so the paywall renders
   with the planned tiers but cannot transact. Swapping in a real
   `PurchaseService` is one class (see the subscription-products item
   above), but it cannot happen before a build is on a Play track.
3. **Premium is a fence, not a wall.** `FreeLimits` is enforced in the
   client only; the backend has no `subscriptions` table yet, so the API
   still answers requests a free tier should not be making. Accepted for
   the first release, and written down in `premium_gate.dart` so it is not
   mistaken for enforcement.

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
5. **iOS needs an Apple Developer account.** The app itself now builds and
   runs — see [Deployment — iOS](#deployment--ios) below for what was
   verified and what is left.

---

# Deployment — iOS

Verified on a Mac on 2026-08-22: Xcode 26.5 (17F42), Flutter 3.44.1,
macOS 26.5.2. The `ios/` directory is no longer just `flutter create`
scaffolding — it compiles, signs-less-archives, and runs.

## What actually built

```
flutter analyze                                    clean
flutter test                                       34 passed
flutter build ios --release --no-codesign          Runner.app, 20.7 MB
flutter build ios --simulator --debug              launched on iPhone 17
```

The simulator run reaches the login screen, picks up the system locale,
and renders the branded droplet. Nothing in the Dart layer is
Android-specific.

## No Podfile — plugins come from Swift Package Manager

`flutter doctor` warns that CocoaPods is missing, and it is a red herring
here. Flutter 3.44 resolves iOS plugins through SPM: the Xcode project
carries an `XCLocalSwiftPackageReference` to
`ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage`, and all
four iOS plugins — `shared_preferences_foundation`, `image_picker_ios`,
`flutter_timezone`, `flutter_local_notifications` — resolve from there. No
`ios/Podfile` is generated and none is needed.

CocoaPods 1.17.0 is installed on the build Mac anyway (`brew install
cocoapods`), because a plugin added later that has no SPM support makes
Flutter fall back to it silently.

**Do not follow a `cd ios && pod install` instruction from older notes.**
It will not produce a Podfile and it is not what builds this app.

## Info.plist keys that are not optional

`flutter create` does not add usage-description strings, and their absence
is not a warning — iOS kills the process the moment the API is touched.
`image_picker` drives both the camera and the library from the avatar
sheet, so both keys are required:

| Key | Why |
|---|---|
| `NSCameraUsageDescription` | Profile → avatar → "Take a photo". Missing ⇒ hard crash. |
| `NSPhotoLibraryUsageDescription` | Profile → avatar → "Choose from gallery". Missing ⇒ hard crash. |
| `ITSAppUsesNonExemptEncryption` = `false` | Otherwise App Store Connect asks the export-compliance question on *every* upload. HTTPS-only counts as exempt. |
| `CFBundleLocalizations` = en, de, ru, uk | Without it the store listing claims the app is English-only, whatever `easy_localization` does at runtime. |

`CFBundleDisplayName` was `Water App Mobile`; it is now `Water App`, which
is what Android's `strings.xml` and the login header already said.

The permission strings themselves are English-only. They live in
`Info.plist`, not in `assets/i18n`, so translating them means adding
`ios/Runner/<lang>.lproj/InfoPlist.strings` for de/ru/uk and registering
those files in the Xcode project. Cosmetic, not blocking.

## ATS: nothing to do

The README's old iOS note said to edit `Info.plist` to allow cleartext.
Don't. App Transport Security defaults to HTTPS-only, which is exactly the
posture `src/main/res/xml/network_security_config.xml` gives the Android
release build. Adding an `NSAppTransportSecurity` exception would both
weaken the shipped app and invite a review question. Point the app at an
HTTPS backend instead — the same blocker Play has.

## Privacy manifests

Apple's required-reason API rules are already satisfied: the Flutter
framework and all four plugins bundle their own `PrivacyInfo.xcprivacy`,
visible in the built product. The Runner target itself has no
`PrivacyInfo.xcprivacy` and does not need one — the Dart layer touches no
required-reason API directly.

What still has to be filled in by hand is the App Store Connect privacy
questionnaire, and it is the same data inventory as Play's Data Safety
form: email + name, health/fitness (birth date, weight, height), photos
(avatar), app activity (drink logs) — all linked to the account, all
deletable in-app.

## App Store submission checklist

- [ ] **Apple Developer Program membership**, $99/yr. Nothing below is
      possible without it.
- [ ] **Register the bundle ID.** iOS uses `com.vovafes.waterAppMobile`,
      Android uses `com.vovafes.water_app_mobile` — they differ because
      iOS bundle IDs cannot contain underscores. Both are permanent from
      first publish. Settle the naming question (see "`applicationId`"
      above) once, for both platforms, before either ships.
- [ ] **Set `DEVELOPMENT_TEAM`.** The Xcode project has
      `CODE_SIGN_STYLE = Automatic` and no team. Open
      `ios/Runner.xcworkspace`, pick the team under Signing & Capabilities,
      and let Xcode create the profile.
- [ ] **Push Notifications capability is not needed.** Reminders are
      *local* notifications; the plugin asks for permission at runtime and
      no APNs entitlement is involved. Adding the capability would create
      an entitlement the app never uses.
- [ ] **Privacy policy URL.** Same blocker as Play — the page exists at
      `/privacy` on the backend but has no public host.
- [ ] **Account deletion.** Already in-app (Profile → Delete account).
      Apple requires this for any app with in-app registration, same as Play.
- [ ] **Screenshots.** Required at 6.9" and 6.5"; iPad sizes too if the app
      is not marked iPhone-only. `LSRequiresIPhoneOS` is set but the target
      is still Universal, so decide which.
- [ ] **Archive and upload:**
      ```bash
      flutter build ipa --release --dart-define=API_BASE_URL=https://<host>
      ```
      then upload `build/ios/ipa/*.ipa` with Transporter, or
      `xcrun altool`/`xcrun notarytool` from CI.

## Known iOS-side gaps

1. **Launch screen is blank white.** `Assets.xcassets/LaunchImage.imageset`
   still holds the three 68-byte placeholder PNGs from `flutter create`, so
   a dark-mode phone flashes white before the first Flutter frame. Not a
   rejection risk, but Android has a themed launch and iOS does not.
2. **App icon has the corner radius baked in.** `make-icon.ps1` draws a
   rounded square at r=200 and `remove_alpha_ios: true` flattens the
   corners to white. The iOS mask is a slightly *larger* radius, so it
   clips inside the baked corner and no white shows — it renders correctly
   today. Apple's HIG still asks for a full-bleed square; worth fixing when
   the icon is next regenerated.
3. **`make-icon.ps1` and `make-keystore.ps1` are Windows-only** —
   `System.Drawing` plus a hardcoded `C:\dev\...` output path. Neither is
   needed for an iOS build (signing is Xcode's job), but the icon script has
   no Mac equivalent, so re-rendering the icon means a Windows machine or a
   rewrite.
4. **Foreground notification banners are untested on iOS.** Scheduled
   reminders fire from the OS whether or not the app is running, but
   displaying a banner while the app is in the foreground depends on
   `UNUserNotificationCenter`'s delegate. Verify on a real device before
   release.

## Verified end-to-end: offline behaviour

Every `ApiService` verb now funnels through `_send()`, which converts a
transport failure into the ordinary `{success: false, status: 0}` envelope
and caps each request at 20 s. Before that, a `ClientException` was thrown
straight out of the `await` in `AuthProvider.login()`, skipping
`_loading = false` — the login button spun forever with no error and no way
back. Apple reviews on their own network and tests airplane mode; a stuck
spinner is a standard Guideline 2.1 rejection.

Confirmed on the simulator against an unreachable host: the login screen
shows "Нет соединения с сервером" and re-enables the button.
