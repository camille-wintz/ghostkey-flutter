# Themes on the phone — the plan

Written 2026-09-22, the day the desktop and the server got themes. Nothing
here is built. The desktop side it has to match is `ghost-key/src/shared/
themes/` (one folder per theme) and `ghost-key/src/shared/design/` (the
elements a theme may redraw); the contract is `GET`/`PATCH
/api/me/preferences` in `../ghostkey-server/openapi.yaml`. Themes are
**night** and **day** for now, with more to come.

## What the account already says

`GET /api/me/preferences` answers `{ "theme": "night" | "day" | … | null }`.
The slug is client vocabulary — the server validates the shape
(`[a-z0-9-]{1,32}`) and never the name — and `null` means never chosen.
`PATCH` takes a partial body (`{ "theme": "day" }`, or `null` to clear) and
answers the whole record. Both are `Auth`-tagged, per account.

The desktop's rule for the two copies, which the phone should keep:

- The **account wins** once signed in: read on sign-in and on every resume.
- The **device caches** the name for the first frame.
- A **never-chosen account adopts the device's cache** (one `PATCH`), so a
  signup that arrived through a themed landing opens in that theme. On the
  phone that case is rarer, but the rule costs nothing and keeps the two
  clients agreeing.
- An **unknown name falls back to night** on the client, silently; a newer
  desktop may have stamped a theme this build does not ship.

## Three steps, in order

### 1. The preference itself

- `lib/server/preferences/api.dart` — `getMyPreferences()` and
  `setMyTheme(String? name)` over `apiFetch`, modelled on
  `lib/server/rewards/api.dart`.
- `lib/server/dto/preferences.dart` — `Preferences { String? theme }` with
  `fromJson`, hand-written like the others; diff it against `openapi.yaml`
  (`components.schemas.Preferences`).
- A Riverpod provider for the theme name: seeded from the device cache before
  `runApp`, replaced by the account's answer when the session is up, refreshed
  on `AppLifecycleState.resumed` (the desktop refetches on window focus; this
  is the same moment).
- **Cache:** add `shared_preferences` — the name is not a secret, and
  `flutter_secure_storage` is for tokens. Key it `ghost-key-theme` so a
  grep across the workspace finds every reader (the desktop's are
  `src/shared/themeCache.ts` and `public/theme-boot.js`).
- A switch on Account (or wherever the settings live): it applies the theme,
  writes the cache, PATCHes. Disabled offline, like the desktop's picker —
  the choice is the account's, and a write that cannot land is undone by the
  next sign-in.

### 2. Tokens that can change

[lib/ds/tokens.dart](../lib/ds/tokens.dart) is a static class with ~994 `Ds.*`
references across ~173 files, and its own header already anticipated this:
"a second object and a theme read, not a rewrite of every call site".

- Make `DsTokens` a plain class holding every colour the spine has (surfaces,
  inks, hairlines, washes, accent ramp, the three meaning ramps
  `attention`/`danger`/`done` — the desktop renamed amber/red/emerald to
  those on 2026-09-22 — the plan ladder, glass), one `const` instance per
  theme.
- Keep `Ds.void_` as the call syntax: every static getter reads
  `Ds.current.void_`, where `current` is swapped by the provider. That is
  one file and a global, which is the tradeoff; the clean path (tokens from
  `BuildContext`) is 173 files and can come later, slot by slot.
- Rebuild the tree on a switch: `MaterialApp` keyed on the theme name, and
  `buildTheme(tokens)` in `app.dart` takes the instance instead of reading
  the statics (`brightness` from the theme's colour scheme, not hard-coded
  dark).
- **Day flips the ink steps.** On the desktop `attention-200/300` are pale on
  night and dark on paper, so a caller never says which theme it is in. Mirror
  the same values; do not invent a second light ramp.

### 3. Stop mirroring by hand

The phone's tokens are on the **old** palette already: `Ds.void_` is
`0x0a0914` where the desktop's night is `#131822`, `panel` `0x0c0d15` vs
`#090b0e`, and so on down the ramp. The theme work is the moment to fix
that once and for all:

- A script in `ghost-key/` (say `pnpm ds:flutter`) that reads
  `src/shared/tokens.css` (night, the base) and every
  `src/shared/themes/*/tokens.css` (the re-fills) and writes
  `lib/ds/tokens.dart`'s colour block — one `DsTokens` instance per theme,
  generated, with a header saying so. Type scale, geometry and motion can
  stay hand-written; they are not themed.
- Fonts are bundled TTFs here (`pubspec.yaml` `fonts:`), so a theme that
  brings a face (`fontsHref` on the desktop manifest) means adding the TTF
  and a `family` entry; night and day share the three the app has.

## What stays off the phone

- The desktop's **design slots** (a theme redrawing Button, the launcher
  backdrop, …). Tokens and fonts get a Flutter theme most of the way; a
  redrawn widget per theme is a later decision, and the phone has no
  launcher stage to redraw anyway.
- Any theme name outside the generated token file and the provider's
  fallback. Nothing may branch on `"day"`.

## Order of work

1 is independent and small. 2 is the real change and can ship with night
only (one instance, no visible difference) to prove the refactor. 3 makes
day appear by generation rather than by hand, and fixes the palette drift
as a side effect.
