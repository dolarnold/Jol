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

Sign-up and login currently provide client-side form validation only. They do
not send verification codes or create accounts; connect them to the existing
authentication API once its base URL, auth method, and endpoint documentation
are available.

## Tests

```shell
flutter analyze
flutter test
```
