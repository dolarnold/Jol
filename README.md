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
  - Scan tickets at the door, see the guest list and handle staff requests.
- **Inbox:** notifications, push notifications, support messages and account
  warnings.
- **Theme:** dark and light mode.

Casual hosts are capped at R250 per ticket, 400 people and R20,000 per event.
Commercial hosts manage their events on the website instead.

## Tech stack

Flutter (Dart 3.13+), Riverpod 3, go_router, Dio, flutter_secure_storage (for
the bearer token), google_maps_flutter, geolocator, image_picker,
firebase_messaging, qr_flutter and share_plus.

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
flutter run --dart-define=API_BASE_URL=https://jol-backend-production-xgp5ka.laravel.cloud/api/v1
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
   adds `google-services.json` (Android), `GoogleService-Info.plist` (iOS) and
   the Gradle setup.
3. iOS only: in Xcode, add the **Push Notifications** capability and
   **Background Modes → Remote notifications**. Then upload an APNs key in
   Firebase → Project settings → Cloud Messaging.
4. In the website's superadmin, open **Integrations & API Keys** and paste the
   Firebase **service account** JSON from the same project.

Without step 2 the app still runs, but without push.

## Project layout

```
lib/main.dart, lib/app.dart   Entry point, router and theme
lib/data/                     API client, auth, booking and push repositories
lib/features/discover/        Feed, event page, event models
lib/features/booking/         Checkout and tickets
lib/features/hosting/         Create/edit events, door scanning, guests
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
