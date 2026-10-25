# Camsur AI Studio — Flutter AI Photo App

Part of the [Camsur AI Studio monorepo](../README.md). A Flutter app that turns everyday selfies into studio-quality photos: headshots, passport photos, background edits and more.

It talks to the Camsur backend, which lives next to it in this repo: [camsur-backend](../camsur-backend).

## Features

- Email and password sign up, plus Google and Apple sign-in
- Browse AI photo tools and pick a style
- Upload a photo and get the result
- Before and after comparison
- Credits balance and credit packs
- Save or share your results
- Light and dark themes

## Tech stack

- Flutter (Dart 3)
- [GetX](https://pub.dev/packages/get) for state, routes and dependency injection
- [Dio](https://pub.dev/packages/dio) for networking
- Android, iOS, macOS, web, Windows and Linux project folders

## Quick start

You need [Flutter](https://docs.flutter.dev/get-started/install) installed and the [backend](../camsur-backend) running.

```bash
# 1. Get the code
git clone https://github.com/suraj-chavda/Camsur-AI-Studio.git
cd Camsur-AI-Studio/camsur-flutter

# 2. Install packages
flutter pub get

# 3. Run (point the app at your backend)
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

Tips:
- The Android emulator cannot reach `localhost`. Use `http://10.0.2.2:8000/api/v1` instead.
- On a real phone, use your computer's local IP address, for example `http://192.168.1.10:8000/api/v1`.

## Settings

Settings are passed with `--dart-define`. Nothing secret is stored in the code.

| Name | What it is | Default |
|---|---|---|
| `API_BASE_URL` | Your backend address | `http://localhost:8000/api/v1` |
| `GOOGLE_SERVER_CLIENT_ID` | Google **Web** OAuth client ID (for Google sign-in) | empty |
| `GOOGLE_IOS_CLIENT_ID` | Google **iOS** OAuth client ID | empty |
| `ONBOARDING_ASSETS_BASE_URL` | Public URL of your onboarding images | placeholder |

Example:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=your-id.apps.googleusercontent.com
```

## Optional: Google and Apple sign-in

Email sign-in works without any extra setup. For Google or Apple:

1. Turn on the provider in your Supabase dashboard (Authentication → Providers).
2. Create your own OAuth client IDs in Google Cloud / Apple Developer.
3. On iOS, replace `REPLACE_WITH_IOS_CLIENT_ID` in `ios/Runner/Info.plist` with your reversed client ID.
4. Pass the client IDs with `--dart-define` as shown above.

## Make it your own

The app ID is `com.zennagraph.camsur`. Change it to your own before publishing to a store (Android: `android/app/build.gradle.kts`; iOS and macOS: Xcode project settings).

## Project layout

```text
lib/
  app/        App setup, routes, bindings
  core/       Theme, widgets, networking, helpers
  data/       Models, repositories, sources
  features/   Screens (auth, home, tools, credits, ...)
```

## Run the tests

```bash
flutter test
```

## License

[MIT](../LICENSE) © 2026 Suraj Chavda
