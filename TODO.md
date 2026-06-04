# TODO

Tracked open items for the Water App mobile / backend pair. Items here
are not blocking the current APK but should be addressed before the
app sees real distribution.

## Mobile + backend

### Profile photo / avatar (blocked on backend)

The Flutter Profile screen renders the user's first initial inside a
sky→cyan gradient circle. To support real photos:

**Backend (water-app):**
1. Migration: `add_avatar_path_to_users` — `string('avatar_path')->nullable()`
2. `App\Models\User`: append `avatar_url` accessor that prefixes
   `Storage::disk('public')->url($avatar_path)` (or returns `null`)
3. `App\Http\Controllers\Api\V1\ProfileController`:
   - `uploadAvatar(Request $request)` — validate `image|max:5120`, resize to
     ~512×512 via Intervention Image (already in vendor), store on the
     `public` disk under `avatars/{user_id}.{ext}`, save the path.
   - `deleteAvatar()` — remove file + null the column.
4. Routes (`routes/api.php`):
   ```php
   Route::post('profile/avatar',   [ProfileController::class, 'uploadAvatar']);
   Route::delete('profile/avatar', [ProfileController::class, 'deleteAvatar']);
   ```

**Mobile (water-app-mobile):**
1. Add `image_picker: ^1.x` to `pubspec.yaml`.
2. Add `User.avatarUrl` field.
3. Add `multipart` POST helper to `ApiService`.
4. On Profile screen, wrap the avatar circle in a tap handler →
   bottom sheet with "Take photo / Choose from gallery / Remove" →
   upload, then call `AuthProvider.refreshUser()` to redraw.

## Mobile

### Drink icon images
The backend returns `icon_path` for each drink (`/storage/drink-icons/...`).
Mobile currently renders an emoji fallback keyed off the category slug.
Switch to `Image.network(drink.iconUrl!)` with the emoji as the
`errorBuilder` once you've confirmed the icon assets are uploaded via
the Filament admin.

### iOS build
`ios/` exists but is unbuilt. See README for what a Mac-side build
requires.

### Cleartext HTTP → HTTPS
`AndroidManifest.xml` carries `usesCleartextTraffic="true"` so the
release APK can talk to the dev `http://192.168.2.100:8000`. Drop
this flag and switch the base URL to `https://...` before any real
distribution.

### `shared_preferences_android` KGP warning
The plugin still applies the old Kotlin Gradle Plugin. Future Flutter
releases will reject this. Upgrade when its next major drops.

## Backend (water-app)

### Drink categories
Mobile's drink chip emoji is keyed off the category slug. New categories
added via Filament admin will fall back to a generic 🥤 — update
`Drink.emojiFallback` in `lib/models/drink.dart` when adding new slugs.

### Drink icon assets
Run `php artisan storage:link` (done automatically by the Docker
entrypoint) and upload SVG/PNG icons via Filament so the mobile app
can render them.

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
