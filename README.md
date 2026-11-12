# JOL

A Flutter app for discovering and hosting events in Cape Town.

## Run locally

```shell
flutter pub get
flutter run
```

The app opens with the JOL splash screen, followed by welcome, sign-up, and
login. Choose **Look around first** to enter the five-tab shell without signing
in. The theme button switches between dark and light mode.

The attendee sign-up and login screens call the Laravel API. The app loads
public events and event details from the same API. Secure bearer tokens are
stored using the platform's secure storage.

The default API URL targets Laravel's local development server. From the
Laravel project, start the API so an Android emulator can reach it:

```shell
php artisan serve --host=0.0.0.0 --port=8000
```

For Android emulator or local desktop development, the default URLs are
`http://10.0.2.2:8000/api/v1` and `http://127.0.0.1:8000/api/v1`
respectively. For a physical device or deployed server, supply the API URL
including `/api/v1` at build/run time:

```shell
flutter run --dart-define=API_BASE_URL=https://your-api.example.com/api/v1
```

Live event browsing is connected. RSVP submission and ticket checkout still
need to be wired to the Laravel API.

## Tests

```shell
flutter analyze
flutter test
```
