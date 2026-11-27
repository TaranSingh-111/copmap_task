# CopMap

CopMap is a duty management and officer monitoring application. The Flutter app is used by **OFFICER** accounts and **ADMIN** accounts; both authenticate against the same Supabase project. Admin users manage officers and duties and view current officer locations. Officers view assigned duties, update duty status, and share location while a duty is in progress.

## Current capabilities

- Email and password authentication with persistent Supabase sessions.
- Role-based entry to the Admin or Officer experience, based on the authenticated user's profile.
- Admin dashboard with duty metrics, officer list, duty creation/editing/cancellation, and the live officer map.
- Admin-only officer account creation through the `create-officer` Supabase Edge Function.
- Officer duty list and details, with duty start/complete transitions sent through the `update_duty_status` RPC.
- Officer GPS collection and upload to `officer_locations` while an officer has an in-progress duty.
- Admin live locations and a corresponding officer location list, with Realtime updates and freshness labels.

GPS tracking and live map behavior depend on device permissions, platform configuration, Google Maps configuration, and the Supabase policies/publication described below.

## Technology

- Flutter and Dart
- GetX for dependency injection, state management, and navigation
- Supabase Auth, PostgreSQL, Edge Functions, and Realtime
- Geolocator for location collection
- Google Maps Flutter for the Admin map

## Project layout

The app is organized by feature, with shared services and data access kept outside the views:

```text
lib/
  main.dart
  core/
    config/       # App colors and shared ThemeData
    services/     # Authentication and location services
  data/
    models/       # Duty, profile, location, and map models
    repositories/ # Supabase queries and function invocation
  modules/
    auth/         # Auth binding, controller, gate, and login
    admin/        # Dashboard, duty management, officer creation, live map
    officer/      # Officer dashboard, duty screens, tracking status
  routes/
supabase/
  config.toml
  functions/
    create-officer/
      index.ts
```

Widgets call GetX controllers; controllers coordinate screen state and use repositories/services. Supabase queries are kept in repositories. The Admin map uses a page-scoped controller/realtime subscription; the officer's location collection/upload pipeline is separate from map rendering.

## Requirements

Install and configure:

- Flutter SDK compatible with the Dart constraint in `pubspec.yaml`
- Android Studio or Xcode for platform builds
- A Supabase project configured with the CopMap tables and policies
- Google Maps Platform keys for the platforms where the map will run
- Supabase CLI only if deploying Edge Functions from a terminal

## Local configuration

### Supabase app credentials

1. Copy `.env.example` to `.env`.
2. Fill in the Supabase project URL and the **publishable/anon client key**:

   ```dotenv
   SUPABASE_URL=https://<project-ref>.supabase.co
   SUPABASE_ANON_KEY=<publishable-or-anon-key>
   ```

3. Keep `.env` local. It is ignored by Git. The app loads it in `lib/main.dart` and initializes the shared Supabase client before launching the app.

The client key is not a service credential. **Never place the Supabase service-role key in `.env`, Flutter code, app assets, or a mobile build.** The service-role key belongs only in Supabase Edge Function secrets.

### Google Maps keys

Use separate restricted keys where practical. Restrict each key to the required Maps API and the relevant platform identity.

- **Android:** Copy `android/maps.properties.example` to `android/maps.properties` and set `MAPS_API_KEY=<restricted-android-key>`. Gradle reads this file and supplies the manifest placeholder.
- **iOS:** Copy `ios/Flutter/Maps.xcconfig.example` to `ios/Flutter/Maps.xcconfig` and set `MAPS_API_KEY = <restricted-ios-key>`.
- **Web:** Copy `web/maps-config.js.example` to `web/maps-config.js` and set `window.COPMAP_MAPS_API_KEY` to a key restricted to Maps JavaScript API and your local/deployed website referrers. `web/index.html` loads the Maps JavaScript API before Flutter starts, so `google.maps` is available when the Flutter map widget initializes.

The local config files are ignored by Git. Do not commit real keys. A Maps browser key is visible to users at runtime; protect it with Google Cloud API and HTTP referrer restrictions.

### Install and run

From the project root:

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

For a debug Android APK:

```sh
flutter build apk --debug
```

## Supabase backend

The app expects these tables:

### `profiles`

- `id`: Auth user UUID and profile primary key
- `full_name`
- `role`: `ADMIN` or `OFFICER`
- `created_at`

A database trigger may create an `OFFICER` profile when an Auth user is created. The officer creation function upserts by profile ID, setting the supplied full name and `OFFICER` role, so an existing trigger-created row is updated rather than duplicated.

### `duties`

The current app uses the established fields: `id`, `title`, `description`, `location_name`, `latitude`, `longitude`, `assigned_to`, `status`, `start_time`, `end_time`, `created_by`, `created_at`, and `updated_at`.

Duty statuses are `PENDING`, `ASSIGNED`, `IN_PROGRESS`, `COMPLETED`, and `CANCELLED`. Officer status transitions call the existing `update_duty_status` RPC; Flutter does not directly update duty status.

### `officer_locations`

The current app expects `officer_id`, `latitude`, `longitude`, `accuracy`, and `updated_at`. Officers upload their own latest location using an upsert keyed by `officer_id`; Admin location reads rely on the existing RLS policy. The table must be included in the `supabase_realtime` publication for live updates.

### `alerts`

The table exists in the backend, but emergency alert workflows are not currently part of this app implementation.

**Do not apply broad RLS changes to make the client work.** Keep role checks and data access rules enforced by Supabase. Confirm the project's existing policies permit the intended operations for the authenticated role.

## Deploying officer account creation

The Admin dashboard invokes `create-officer`. The Edge Function:

1. Requires a valid bearer access token.
2. Verifies the caller with Supabase Auth and loads the caller profile.
3. Rejects requests unless the profile role is `ADMIN`.
4. Creates an Auth account using the Admin Auth API.
5. Sets `full_name` and `OFFICER` in the profile.
6. Does not accept a role from the client.

The function is configured with JWT verification in `supabase/config.toml`. It reads `SUPABASE_SERVICE_ROLE_KEY` from the Edge Function environment; this key is never sent to the app.

To deploy:

1. Link the Supabase CLI to the intended project (or select the project in the Supabase Dashboard).
2. In **Supabase Dashboard → Edge Functions → Secrets**, set `SUPABASE_SERVICE_ROLE_KEY` to the project's service-role key. Do not put the value in source control or send it to Flutter.
3. Deploy the function from the project root:

   ```sh
   supabase functions deploy create-officer --project-ref <project-ref>
   ```

4. Confirm the function is deployed and its logs show no configuration errors.
5. Test with an Admin account, then verify the created Auth user and `profiles` row have the same UUID and the profile role is `OFFICER`.

The function creates confirmed email accounts so officers can sign in immediately using the credentials issued by an Admin. Follow your organization's process for securely delivering temporary passwords and changing them afterward.

## Location permissions and behavior

The Android manifest declares foreground, fine/coarse, and background location permissions, location foreground service permissions, notification permission, and wake lock. Android and device versions may still prompt users separately for foreground/background access and notifications.

The officer must grant foreground location permission and enable device location. Background permission is needed for tracking to continue when the app is not visible; without it, tracking may be limited to foreground use. Users can choose approximate location on supported Android versions. The app should clearly show tracking/permission state.

Test background collection on physical devices, since battery optimization, vendor power management, and Android version affect delivery. A message that tracking is active indicates collection is running; successful uploads should be confirmed separately in Supabase.

## Admin live map prerequisites

- A restricted Google Maps key is configured for the target platform.
- Admin users have read access to profiles, duties, and officer locations under existing RLS.
- `officer_locations` is in the `supabase_realtime` publication.
- The Admin view marks locations updated within two minutes as current and older locations as stale; officers without a location row are shown without a location.

If Realtime cannot subscribe or Supabase denies a read, fix the intended publication/policy through the Supabase project owner. Do not disable RLS to hide the error.

## Security notes

- Never ship a service-role key in the client.
- Never trust a role supplied by a client request.
- The Edge Function verifies both the caller's Auth token and ADMIN profile.
- Account creation is exposed from the Admin experience, and the backend independently rejects non-admin requests.
- Keep API keys restricted and local configuration files out of Git.
- Do not weaken RLS or expose credentials in logs, screenshots, issue trackers, or this README.

## Verification checklist

After deploying backend changes and configuring a test project:

- [ ] Admin can create an officer.
- [ ] The resulting Auth user has a matching profile with role `OFFICER`.
- [ ] The new officer can sign in and is routed to the Officer dashboard.
- [ ] An officer cannot access Admin UI or Admin operations.
- [ ] Direct invocation by an officer receives a forbidden response.
- [ ] Duplicate email and password policy errors are understandable in the UI.
- [ ] Creating an officer leaves the Admin session active and refreshes the officer list.
- [ ] Officer duty start/complete uses the RPC, and tracking starts/stops with the active duty lifecycle.
- [ ] Admin live-map RLS and Realtime access work without bypassing security.

## Useful references

- [Flutter documentation](https://docs.flutter.dev/)
- [Supabase Flutter quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [Supabase Edge Function secrets](https://supabase.com/docs/guides/functions/secrets)
- [Supabase Auth Admin create-user reference](https://supabase.com/docs/reference/javascript/auth-admin-createuser)
