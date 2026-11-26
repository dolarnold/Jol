# JOL

A Flutter app (Android and iOS) for discovering, booking and hosting events in
Cape Town. It talks to the JOL Laravel backend (`Jol_backend`) through its
`/api/v1` API and never connects to the database directly.

## Features

- **Getting started:** splash, welcome, sign-up and login. You can also choose
  **Look around first** to browse the five-tab shell without an account.
- **Discover:**
  - Browse the public event feed and the Top List.
  - Use **Near me**, or browse events on a map.
  - Open private events by invite code.
- **Event page:**
  - A poster, plus a map with directions. Private locations stay hidden until
    you're booked.
  - Ticket types, the contribution fund, 18+ and plus-one details.
  - Contact the organiser, report the event, or request to promote it.
- **Booking:** RSVPs (with limit and cutoff), ticket checkout, My Tickets with
  QR codes, and ticket transfer.
- **Hosting (casual hosts):**
  - Create, edit, preview and save events as drafts.
  - Add a cover image and pick a location on Google Maps.
  - Add multiple ticket types, a contribution fund, a poster style and RSVP
    rules.
  - See the guest list and handle door staff requests.
- **At the door** (for the host, co-hosts and door staff):
  - Scan tickets with the camera, or type the code.
  - Tick RSVP guests off by name, with plus-ones and walk-ins.
  - Sell tickets at the door for cash or the host's own card machine.
  - Works without signal: save the list before doors open, and it syncs later.
- **Inbox:** notifications, push notifications, support messages and account
  warnings.
- **Theme:** dark and light mode.

Casual hosts are capped at R250 per ticket, 400 people and R20,000 per event.
Commercial hosts manage their events on the website instead.

## Tech stack

Flutter (Dart 3.13+), Riverpod 3, go_router, Dio, flutter_secure_storage (for
the bearer token), google_maps_flutter, geolocator, image_picker,
firebase_messaging, qr_flutter, share_plus, mobile_scanner (the door camera),
and crypto and path_provider (the door list for no signal).

## Run locally

```shell
flutter pub get
flutter run
```

The API URL defaults to Laravel's local development server:

- Android emulator: `http://10.0.2.2:8000/api/v1`
- Desktop: `http://127.0.0.1:8000/api/v1`

Start the backend so the emulator can reach it:

```shell
php artisan serve --host=0.0.0.0 --port=8000
```

For a physical device, or to use the live server, pass the API URL (including
`/api/v1`):

```shell
flutter run --dart-define=API_BASE_URL=https://jolnow.co.za/api/v1
```

To get demo accounts and events, run
`php artisan db:seed --class=JolFeaturesSeeder` on the backend. Every demo
account's password is `password`, for example `thandi@jol.test` (casual host)
or `kyle@jol.test` (attendee).

## Google Maps

The location picker, event maps, Near me and the Discover map use Google Maps.
Address search goes through the backend (`/api/v1/maps/*`), so the app only
needs a Maps SDK key:

- **Android:** add `GOOGLE_MAPS_API_KEY=your-android-key` to
  `android/local.properties`. This file isn't committed.
- **iOS:** copy `ios/Flutter/Maps.xcconfig.example` to
  `ios/Flutter/Maps.xcconfig` and paste your iOS key. This file isn't
  committed.
- **Backend:** in the website's superadmin, open **Integrations & API Keys**
  and paste the server key. Enable Places API (New) and Geocoding API for that
  key.

On build servers such as Codemagic (`codemagic.yaml`), set
`GOOGLE_MAPS_API_KEY` as an environment variable for Android. For iOS, write
`ios/Flutter/Maps.xcconfig` in a pre-build script.

## Push notifications (Firebase)

1. `flutter pub add firebase_core firebase_messaging`
2. Run `dart pub global activate flutterfire_cli`, then run
   `flutterfire configure` in this folder and pick your Firebase project. This
   adds `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
   The Gradle setup is already in place: it switches on by itself once
   `android/app/google-services.json` exists. If `flutterfire configure` adds a
   second `com.google.gms.google-services` line to the Gradle files, delete the
   extra one.
3. iOS only: in Xcode, add the **Push Notifications** capability and
   **Background Modes → Remote notifications**. Then upload an APNs key in
   Firebase → Project settings → Cloud Messaging.
4. In the website's superadmin, open **Integrations & API Keys** and paste the
   Firebase **service account** JSON from the same project.

Without step 2 the app still runs, but without push.

## Crash reports (Firebase Crashlytics)

1. `flutter pub add firebase_crashlytics`
2. Set up Firebase as in steps 1 and 2 above. There's nothing else to change:
   `lib/main.dart` already sends crashes and uncaught errors, and Android
   switches the Crashlytics Gradle plugin on when `google-services.json` exists.
3. Build a release version (`flutter run --release`), make it crash once, and
   open Firebase → Crashlytics to see the report.

Only release builds send reports, so debugging on your own phone doesn't fill
the dashboard. Reports carry the app version, phone model and the error, never
the user's name, email or number.

## Links that open the app

Tapping a shared event link (`https://…/e/CODE`) opens the event in the app
when it's installed, and in the browser when it isn't. The route is `/e/:code`
in `lib/app.dart`.

- **Android:** already set up in `android/app/src/main/AndroidManifest.xml` for
  the current Laravel Cloud address. In the website's superadmin, open
  **Integrations → App links** and enter the package name (`com.jol.app`) and
  the SHA-256 fingerprint of your signing key. Test with
  `adb shell pm verify-app-links --re-verify com.jol.app`, then
  `adb shell pm get-app-links com.jol.app`.
- **iOS:** `ios/Runner/Runner.entitlements` has the domain, but it isn't
  switched on yet because the Apple app ID needs the Associated Domains
  capability first. On developer.apple.com, tick **Associated Domains** for the
  app ID. Then in Xcode → Runner → Signing & Capabilities, add **Associated
  Domains** (Xcode links the file). Finally enter the Apple Team ID and bundle
  ID under **Integrations → App links**.

When JOL gets its own domain, add it in both files as well.

## At the door

**Staff → Open door**, or **Door: scan, list, sell** in an event's menu on the
hosting screen, opens `lib/features/door/door_screen.dart` for the host,
co-hosts and door staff:

- **Scan:** the camera reads the ticket's QR code
  (`lib/features/door/qr_scanner_view.dart`), or type the code. The answer is
  green (let in), amber (check ID, 18+) or red (don't let in, with the reason).
- **Guest list:** for RSVP events, search by name or the last digits of a
  number, let in all of a party or some of them, undo, and add walk-ins. For
  ticketed events, find a ticket holder by name (for a lost or flat phone).
- **Sell:** tickets at the door for cash, the host's own card machine or other
  (SnapScan, Zapper, EFT). The money goes straight to the host, so JOL takes no
  fee. The host or a co-host switches door sales on for each event.

**No signal.** Tap **Save list** before doors open. The phone keeps a
fingerprint of every ticket code (never the codes), the guest list and the
ticket types, in the app's private folder. Without signal, checks, check-ins and
sales are made against that list and sent when the signal is back (every 45
seconds, or **Sync**). The server has the final say and lists anything that
needs a look, such as a ticket let in on two phones.

The packages it needs (run once):

```shell
flutter pub add mobile_scanner crypto path_provider
```

The camera permission is already in `AndroidManifest.xml` and
`ios/Runner/Info.plist` (`NSCameraUsageDescription`).

## Versions

- **App version.** `version:` in `pubspec.yaml`, e.g. `1.1.0+5`. The part
  before `+` is the version people see. The number after `+` must go up by one
  for every build you upload to the stores.
- **What changed.** Add each release to `CHANGELOG.md`, then tag it:
  `git tag -a v1.1.0 -m "JOL app 1.1.0"` and `git push --follow-tags`.
- **Forcing updates.** The app sends its version with every API request. In the
  website's superadmin, **Integrations → App versions** sets the oldest version
  allowed (older apps get an "Update JOL" screen they can't close) and the
  latest version (older apps get a note they can close). The app checks on
  start-up (`lib/data/api/app_version.dart`).

## Project layout

```
lib/main.dart, lib/app.dart   Entry point, router, theme and crash reports
lib/data/                     API client, auth, booking and push repositories
lib/features/discover/        Feed, event page, event models
lib/features/booking/         Checkout and tickets
lib/features/hosting/         Create/edit events, guests
lib/features/door/            The door: scanning, guest list, door sales, no-signal list
lib/features/maps/            Location picker, event map, Discover map
lib/features/inbox/           Notifications and support messages
lib/features/profile/         Profile and settings
lib/features/attendee/        Attendee state
lib/ui/                       Shared widgets and theme
```

## Checks

```shell
flutter analyze
flutter test
```
