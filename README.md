# ghostkey-flutter

**Ghostkey on a phone.** The mobile client of [Ghostkey](https://ghost-key.app),
an AI-assisted writing app. Flutter, Android first.

This repo is one of three siblings that make up the product — the others are
`ghost-key` (the desktop app and the marketing site) and `ghostkey-server` (the
backend, and the source of truth). They live side by side in one workspace
directory but are independent repos with no shared tooling.

The app is **cloud-only**: sign-in is required and every project lives on the
server. There is no local-first mode and no offline project store.

## What's in it

The rooms that make sense in a pocket, and only those:

| Room | What it is |
| --- | --- |
| **Apparition** | The manuscript editor — plus dictation and page scan, which both land text in it. |
| **Veil** | The world bible. |
| **Poltergeist** | Dashboard, word stats, tasks, plan board. |
| **PhantomMemory** | Chat with the book. |

Mara (plotting), Séance (boards) and Glamour (marketing) are desk rooms and
stay on the desktop.

The editor, dictation and scan are the reason this app exists. Quality there is
load-bearing; feature count is not.

## Running it

Flutter 3.47 / Dart 3.13. There is no `.env` — the server URL is a compile-time
define, and a build without one fails on its first read with a message saying so.

```bash
flutter pub get
flutter run --dart-define=GHOSTKEY_SERVER_URL=https://ghostkey-server-staging.fly.dev
```

`.vscode/launch.json` carries staging, prod and LAN configurations, so in an
editor "Run" is enough.

Build a debug APK and put it on a plugged-in phone:

```bash
flutter build apk --debug --dart-define=GHOSTKEY_SERVER_URL=https://ghostkey-server-staging.fly.dev
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Debug builds use the application id `com.ghostkey.mobile.dev`, so a debug and a
release build coexist on the same phone.

## Gates

```bash
flutter analyze
flutter test
```

Those two are the gate before anything is called done — but neither of them is
proof. This app is judged on how it feels on a real device, so a change to
anything visible gets built, installed and looked at.

## Contributing

There are no branches and no pull requests here: work lands on `main`. See
[CLAUDE.md](CLAUDE.md) for the architecture, the layout of `lib/`, and the
conventions — it is written for both people and agents.
