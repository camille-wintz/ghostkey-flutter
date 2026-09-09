# Ghostkey (Flutter)

**This repo is the Ghostkey mobile app.** It was ported in September 2026
from `ghostkey-mobile` (Expo / React Native), which has since been deleted:
the RN editor and recorder could not be made to feel right on a mid-range
phone, so that app never shipped and the Flutter decision is final. Don't
propose going back, and don't treat the old repo as a source you can still
read — it is gone, and what survived of it is
[docs/orientation-from-react-native.md](docs/orientation-from-react-native.md),
the concept map plus the places React intuition is wrong here.

Cloud-only: sign-in required, every project lives on `../ghostkey-server`.
**The editor, dictation and scan are the selling point; quality is
load-bearing, feature count is not.**

The rooms this app carries: **Apparition** (the editor), **Veil** (the world
bible), **Poltergeist** (dashboard, words, tasks, plan board), **PhantomMemory**
(chat), plus dictation and scan landing in the editor. Mara, Séance and
Glamour are desk rooms and never come here.

## Stack

- **Flutter 3.47 / Dart 3.13**, Android first (`applicationId
  com.ghostkey.mobile`; debug builds get a `.dev` suffix so a debug and a
  release build coexist on the same phone). iOS is in the tree but not built.
- **State**: `flutter_riverpod` 3. Two `Notifier`s hold app state —
  [lib/auth/session.dart](lib/auth/session.dart) (the session, hydrate,
  refresh) and [lib/store/active_project.dart](lib/store/active_project.dart)
  (the open project + active chapter). Every server read is a `FutureProvider`
  in [lib/server/providers.dart](lib/server/providers.dart); a mutation is a
  plain call to an `api.dart` function followed by `ref.invalidate(...)`.
- **Server**: [lib/server/client.dart](lib/server/client.dart) —
  `apiFetch` (buffered) and `apiStream` (for SSE). Mints a request id per
  call, sends `x-request-id`, logs one line per request in debug builds,
  retries once after a refresh on 401. `ServerError` carries the wire code;
  `messageFor(e)` words it. DTOs are hand-written in `lib/server/dto/` with
  `fromJson` readers — diff them against `../ghostkey-server/openapi.yaml`
  when the contract moves.
- **Design system**: [lib/ds/tokens.dart](lib/ds/tokens.dart) mirrors the
  suite's token files by name (`Ds.*` colours, `DsText` ramp, `DsGeom`,
  `DsMotion`, `DsStyle.ui/prose/eyebrow`). Night only. Fonts are bundled
  TTFs (Manrope = the app's words, Newsreader = titles, Spectral = the
  manuscript page only). Icons are Lucide via `lucide_icons_flutter`; the
  room marks are inline SVG in `lib/rooms/icons.dart`.
- **Primitives** in `lib/ui/`: `Press` (the house press, no ripple),
  `GkButton`, `GkField`, `BrandTitle` / `Eyebrow` / `UiText`, `showGkSheet`
  + `SheetHeader`, `showNoticeModal`, `StateScreen`. Use these; a size or a
  colour typed at a call site is the tell that something has left the system.
- **Pure logic** in `lib/core/`: `typography` (smart quotes — one text in
  four repos, edit all together), `chapter_search`, `chapter_reorder`,
  `plan_markers`, `dictation_join`, `words`, `dates`. Testable without a
  device; put tests in `test/core/`.

## Navigation

The root ([lib/app.dart](lib/app.dart)) is exactly one of three subtrees:
the sign-in screen, the shelf, or an open book. **The shelf and an open
book are alternative roots, not a stack**: `open(id)` / `close()` on the
active-project notifier IS the navigation. Each subtree has its own nested
`Navigator` and answers Android's back button itself (`HardwareBack`).
Inside a book, `ProjectRoot` loads the project and hosts the project home
plus the rooms; `ProjectScope.of(context)` gives any room the project id,
and `routeForRoom` is the one map from a room to its route. A room draws
`RoomEntering` until its push has landed (`Entered`), then builds itself.

## Layout

```
lib/
  main.dart · app.dart      ProviderScope, theme, the root switch, HardwareBack
  ds/tokens.dart            the design system
  server/                   client · config · errors · sse · tokens · secure_storage ·
                            providers · dto/ · <family>/api.dart · jobs/run_job.dart (poller)
  auth/ store/              session · active project
  core/                     pure modules (see above)
  access/                   capability (optimistic until the snapshot lands) · plans · welcome_notices
  editor/ autosave/         editor_controller · inline_markdown | the autosave owner · draft journal
  dictation/ scan/          recorder channel · session · seam ledger · anchors | camera · OCR · insert
  chat/ veil/ poltergeist/  the logic half of those three rooms (see below)
  rooms/                    the rooms table · marks · tile
  backdrop/                 glow · motes · ambient_motion
  ui/                       the primitives
  screens/
    auth/ shelf/ account/   sign-in · the shelf (home, cards, create, notices) · account
    project/                project_root · project_home · cover · backdrop · room_row · room_entering
    apparition/ veil/ poltergeist/ phantom/   the rooms
```

**A room is two directories.** `screens/<room>/` draws it — widgets only —
and a sibling top-level `<room>/` holds its logic and providers. So Veil's
roster and dossier building live in `lib/veil/`, its screens in
`lib/screens/veil/`; the same split holds for Poltergeist and for chat
(`lib/chat/` + `lib/screens/phantom/`). Apparition is the one that spreads
wider, because the editor, autosave, dictation and scan are each their own
top-level module feeding the same screen. New logic goes in the logic half:
a `screens/` file that grows a notifier is the tell that it belongs next
door.

## Running

There is no `.env`. The server URL is a compile-time define; a build with
none fails on the first read with a message that says so.

```bash
flutter run --dart-define=GHOSTKEY_SERVER_URL=https://ghostkey-server-staging.fly.dev
flutter build apk --debug --dart-define=GHOSTKEY_SERVER_URL=https://ghostkey-server-staging.fly.dev
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.ghostkey.mobile.dev/com.ghostkey.ghostkey.MainActivity
```

`.vscode/launch.json` carries staging / prod / LAN configurations.
`flutter analyze` and `flutter test` are the gates; a debug APK on the phone
is the proof.

## Git

**One branch. No topic branches, no pull requests.** Work is committed to
`main` and pushed to `main`, same as the two sibling repos. The workspace
skills `commit` (this session's own files, one commit, push) and `staging`
(a whole dirty tree cut into a readable series) are the two ways that
happens.

Unlike the siblings, **a push here is not a deploy** — there is no CI and no
staging app for this repo; the app reaches a phone only when someone builds
an APK. That makes pushing cheap, but it also means nothing downstream will
catch a mistake for you: `flutter analyze` and `flutter test` before the
commit are the whole safety net.

**Several agent sessions share this checkout**, so the index may already
hold someone else's staged work. Commit by path — `git add -N <new files>`
then `git commit --only <paths>` — which takes exactly what you name and
leaves the rest alone. Never `git add -A` / `git add .` / `git commit -a` /
`git clean`, never `--force`-push, and never `git stash` or switch branches
to tidy something: that rewrites a tree that is not only yours.

## The workspace

This repo sits beside `../ghost-key` (Electron desktop + the Astro marketing
site) and `../ghostkey-server` (the backend, and the source of truth) in one
directory that is **not** itself a git repo. `../CLAUDE.md` covers what is
shared; read it before a change that crosses a repo boundary.

The two rules that bite from here:

- **`../ghostkey-server/openapi.yaml` is the API contract**, and it is
  server-owned. The DTOs in `lib/server/dto/` are hand-written against it,
  so a server route change means editing them in the same breath — nothing
  regenerates them and nothing warns you when they drift.
- **Push the server first** when a change spans both. A client calling a
  route the deployed server lacks is a broken app; the reverse is harmless.

Also worth knowing: `lib/core/typography.dart` (smart quotes) is one text
living in more than one repo. Edit every copy together or they disagree
about the same manuscript.

## Code style

- One widget per file. Stateful logic longer than a few lines lives in a
  notifier or a plain class, not in a `build`.
- Terse, modern Dart: early returns, `switch` expressions, sealed classes
  for wire unions, records where a class would be ceremony.
- Descriptive names over comments. Comments are for *why* — non-obvious
  intent, gotchas, invariants — never to restate the next line.
- Rendering is a thin projection of state. A `build` never both computes
  and renders.
- Nothing is reported working from `flutter analyze` alone. Build it, put it
  on the phone, look.
