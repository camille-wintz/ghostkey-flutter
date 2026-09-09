# Orientation: reading this app with React Native eyes

For someone who knows the old `ghostkey-mobile` (Expo / React Native) well and
this app less well. That repo has since been deleted, so the comparisons below
are from memory of it rather than links into it. Not a Flutter tutorial — it assumes you read Dart fine and skips
anything you would catch on sight. It covers the places where **React intuition
is actively wrong here**, because those are the ones that fail invisibly.

Written 2026-09-09, after a night spent fixing the RN chapter list's performance
by hand and then discovering this app had solved it by construction.

**Scope, honestly:** this is built from `CLAUDE.md` plus
`lib/screens/apparition/drawer/*`, `lib/store/active_project.dart`,
`lib/server/providers.dart` and `lib/server/client.dart`. The other ~270 files
are unread. Where a claim is a generalisation from those, it says so.

---

## 1. The map

| RN app | Here |
| --- | --- |
| Zustand `activeProjectStore` | `store/active_project.dart` — a Riverpod `Notifier` |
| Zustand `authStore` | `auth/session.dart` |
| React Query cache entry | a `FutureProvider` in `server/providers.dart` |
| `queryClient.invalidateQueries` | `ref.invalidate(someProvider)` |
| `apiFetch` + refresh-on-401 | `server/client.dart`, same shape, same rid tracing |
| `src/lib/*` pure modules | `lib/core/*`, and they are the same algorithms |
| `src/ds.ts` tokens | `lib/ds/tokens.dart` (`Ds.*`, `DsText`, `DsGeom`) |
| `components/ui/*` primitives | `lib/ui/*` (`Press`, `GkButton`, `showGkSheet`) |
| Screen-local `useState` cluster | a `ChangeNotifier` (e.g. `ChapterDrawerState`) |
| `FlatList` + `getItemLayout` | `SliverReorderableList` + `itemExtent:` |
| Hand-rolled drag (`reorder/*`) | Flutter's own, see §3 |

The structural decisions carried over intact: the shelf and an open book are
alternative roots rather than a stack, rooms draw `RoomEntering` until the push
lands, and `core/` stays pure and testable. If you knew why the RN app was
shaped that way, you know why this one is.

---

## 2. Where React intuition misleads

### Rebuild scope is explicit, and it is yours to choose

React re-renders a component subtree and you opt *out* with `memo`. Here,
`ref.watch(p)` rebuilds **this whole widget** whenever `p` changes, and you
narrow it yourself:

```dart
// chapter_drawer.dart — rebuilds on the active chapter only, not on every
// other field of the notifier.
final active = ref.watch(activeProjectProvider.select((p) => p.activeChapter));
```

Two failure directions, and they look nothing alike:

- **Watching too coarsely, too high.** A `ref.watch` of a fat provider near the
  root rebuilds a large subtree on an unrelated field. Cheap to fix once you see
  it; `.select` is the fix.
- **Watching per item, inside a list.** This is the one that cost a night in RN.
  Every row subscribing to a value that changes every frame means every row does
  work every frame. The Dart twin is an `AnimatedBuilder` or `ListenableBuilder`
  *inside* `itemBuilder` listening to something animating. Put it above the list
  and let the list items be dumb.

`chapter_drawer.dart` already does the right thing: one `ListenableBuilder` wraps
the whole drawer body, and the thing it listens to (`ChapterDrawerState`) changes
on query and pending — not per frame.

### Nothing invalidates itself

React Query refetches on staleness and window focus, so a forgotten invalidate
often self-heals. Riverpod caches until told otherwise. **A mutation is an api
call followed by `ref.invalidate(...)` of everything it moved**, and if you
forget, the screen is confidently stale until something unrelated refreshes it.

The drawer threads this explicitly rather than reaching for `ref` mid-class:

```dart
// chapter_drawer_state.dart
/// Drop the project read so it refetches. The drawer never reads stale.
final void Function() refreshProject;
```

This is the failure class that is expensive for you — it renders fine, so you
don't catch it on sight. When adding a mutation, the checklist is: which
providers describe data this just changed, and are all of them invalidated?

### Keys are load-bearing in a reorderable list

`ValueKey('g-$name')`, `ValueKey(doc.id)` and friends aren't ceremony. Flutter
matches widgets to existing elements — and their state, including in-flight
animations — by position unless a key says otherwise. In a list that reorders,
missing or index-based keys attach the wrong animation to the wrong row. It's
the same idea as React's index-as-key rule, and it bites harder here because
more state hangs off the element.

### Lifecycle is manual

`ScrollController`, `TextEditingController` and any `ChangeNotifier` you create
must be disposed in `dispose()`. And after every `await`, check `mounted` before
touching `context` or calling `setState` — the drawer does this consistently:

```dart
if (mounted) unawaited(showRoomAlert(context, ...));
```

This is the Dart cousin of React's setState-after-unmount, except it throws
rather than warning.

### `const` is free, and has no React analogue

A `const` widget subtree is not rebuilt. There's no equivalent habit to carry
over from JSX, so it's the easiest thing to under-use. `flutter analyze` will
nag; let it.

### `build()` may run many times a frame

No side effects, no fetch kick-offs, no `notifyListeners` from inside it. React's
render has the same rule, enforced more gently. This app states it as house
style: *"a `build` never both computes and renders."*

---

## 3. The list lesson, and why it does not port

The most useful thing to know coming from the RN app: **its drag-and-drop
architecture is a workaround for a React Native cost that does not exist here.
Do not port it.**

What happened in RN, measured on the S21 over a 100-chapter book:

| | janky frames | p90 | p99 |
| --- | --- | --- | --- |
| a `GestureDetector` per row | 50–54% | 44–53ms | 69ms (129ms on open) |
| one gesture for the whole list + a hand-built carried-row overlay | 23–32% | 14–15ms | 21–23ms |

In RN each per-row gesture detector is a **native** gesture handler plus a
JS-side subscription, created and destroyed as cells mount and unmount while you
scroll. A hundred of them is a hundred native objects churning. The fix was to
hoist the gesture to the list and resolve the held row arithmetically, and to
draw the carried row once in an overlay instead of letting every row compute its
own transform every frame.

Here, `HoldToDrag` is **per row** — and that is correct:

```dart
// hold_to_drag.dart, in its entirety, essentially
class HoldToDrag extends ReorderableDragStartListener {
  @override
  MultiDragGestureRecognizer createRecognizer() =>
      DelayedMultiDragGestureRecognizer(delay: liftDelay, debugOwner: this);
}
```

A Flutter `GestureRecognizer` is a Dart object that registers with the gesture
arena. No native view, no bridge crossing, no per-cell teardown. The
architecture that was fatal in RN is the idiomatic answer here.

And the two things that took the most work in RN are parameters here:

| Hand-built in RN | Here |
| --- | --- |
| `DragOverlay.tsx` — the carried row, drawn once above the list | `proxyDecorator:` |
| a computed offset table + `getItemLayout` | `itemExtent: DsGeom.row` |
| flattening two groups into one array with per-group indices | two `SliverReorderableList`s in one `CustomScrollView` |

The sliver model is the quiet win: chapters and notes are genuinely two
reorderable lists sharing one scroll view, so neither has to know the other
exists. In RN they had to become one array whose items carried a group tag,
because a `FlatList` is a single list or nothing.

**The transferable rule, not the code:** in either framework, the question is
*what work happens per row per frame*. RN forced a bespoke answer. Flutter's
default answer is already correct — so reach for the framework's list first, and
only hand-roll when you have a measurement saying you must.

---

## 4. Gates

`flutter analyze` and `flutter test` are the equivalent of the RN app's
`typecheck` — necessary, not sufficient. Pure logic in `core/` is testable
without a device and that is where tests belong.

The rule from `CLAUDE.md` is worth repeating because the RN night proved it the
hard way: **nothing is reported working from `flutter analyze` alone. Build it,
put it on the phone, look.** Every confident diagnosis made from reading the RN
code that night was wrong — the gesture detectors, the mount cost, the mapper
subscription, dev-vs-production mode. Only measurement on the device found the
real causes, and only holding the phone judged the fix.
