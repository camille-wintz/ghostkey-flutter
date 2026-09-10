import '../../rooms/rooms.dart';
import '../../server/dto/profile.dart';

// What the author says they came to do, and which room answers it HERE.
//
// The intent is the author's word — `pitch`, not `glamour` — and this map is
// this client's answer to it, which is why it lives beside this client's room
// table rather than in the contract. The desk maps the same five answers to
// seven rooms; the phone has four.
//
// Two of the desk's options are deliberately missing:
//
// - `plot` has no Mara here, so it ends in the CHAT — which is a real answer
//   rather than a fallback, now that the chat can write an outline, start a
//   story map and fill its beats.
// - `pitch` is not offered at all. Glamour has no phone room and nothing here
//   stands in for it, so an option leading nowhere would be worse than one
//   option fewer. The desk offers it after an import; this does not.

class IntentOption {
  const IntentOption({
    required this.intent,
    required this.room,
    required this.label,
    required this.blurb,
    required this.markTitle,
    required this.markBody,
    this.opensChat = false,
  });

  final Intent intent;
  final RoomKey room;
  final String label;
  final String blurb;

  /// What the coachmark on that room's row says once the author lands.
  final String markTitle;
  final String markBody;

  /// Ends in the chat rather than on a room row — `plot`, which has no room
  /// here. The screen opens PhantomMemory instead of marking anything.
  final bool opensChat;
}

const List<IntentOption> _options = [
  IntentOption(
    intent: Intent.plot,
    room: RoomKey.phantom,
    label: 'Work out what happens',
    blurb: 'Talk the shape of it through, and keep what you land on.',
    markTitle: 'Phantom Memory',
    markBody: 'Plotting lives on the desk, but you can work it out here — and what you settle is saved to your plan.',
    opensChat: true,
  ),
  IntentOption(
    intent: Intent.draft,
    room: RoomKey.apparition,
    label: 'Write',
    blurb: 'The page, your chapters, and dictation when your hands are full.',
    markTitle: 'Apparition',
    markBody: 'This is the page. Open a chapter and start — everything else reads what you write here.',
  ),
  IntentOption(
    intent: Intent.worldbuild,
    room: RoomKey.veil,
    label: 'Build the world',
    blurb: 'Characters, places and terms, shared across the series.',
    markTitle: 'Veil',
    markBody: 'The world bible. Add the people and places you already know, and it keeps up with the ones you write.',
  ),
];

List<IntentOption> intentOptions() => _options;

IntentOption intentOption(Intent intent) =>
    _options.firstWhere((o) => o.intent == intent, orElse: () => _options[1]);

/// The intent a landed project should be marked for, or null when there is
/// nothing to mark — the flow was skipped, or it ended in the chat.
IntentOption? markFor(Intent? intent) {
  if (intent == null) return null;
  final match = _options.where((o) => o.intent == intent && !o.opensChat);
  return match.isEmpty ? null : match.first;
}
