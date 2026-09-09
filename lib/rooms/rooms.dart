import 'package:flutter/painting.dart';

import 'icons.dart';

// The rooms the phone can open, as data. The home screen maps over this
// table, so adding a room is one entry and nothing else. The keys are the
// desktop's `RoomKey`s, which are also what the server's plan-access table
// names a whole room by (`room.<key>`).

enum RoomKey { apparition, veil, poltergeist, phantom }

/// Tile backgrounds for the room icons, as `[start, end]` pairs — the
/// desktop's `linear-gradient(151deg, …)`, whose vector is (0,0) → (0.55,1).
/// Copied from ghost-key's `app-icons/gradients.ts`: six shipped rooms keep
/// their colours even though the design canvas has since re-tinted them, by
/// the author's call. Don't "fix" a diff against the canvas without asking.
class TileGradient {
  const TileGradient(this.start, this.end);
  final Color start;
  final Color end;
}

class Room {
  const Room({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.mark,
    required this.tile,
  });

  final RoomKey key;
  final String title;

  /// The desktop's tagline for the room.
  final String subtitle;
  final RoomMark mark;
  final TileGradient tile;

  /// The capability id the access snapshot gates the whole room on.
  String get capability => 'room.${key.name}';
}

const List<Room> rooms = [
  Room(
    key: RoomKey.apparition,
    title: 'Apparition',
    subtitle: 'Write your story',
    mark: RoomMark.apparition,
    tile: TileGradient(Color(0xFF3F63CF), Color(0xFF1F3283)),
  ),
  Room(
    key: RoomKey.veil,
    title: 'Veil',
    subtitle: 'The world bible',
    mark: RoomMark.veil,
    tile: TileGradient(Color(0xFF2E86B8), Color(0xFF123F66)),
  ),
  Room(
    key: RoomKey.poltergeist,
    title: 'Poltergeist',
    subtitle: 'Words, tasks and the plan',
    mark: RoomMark.poltergeist,
    tile: TileGradient(Color(0xFFC08D33), Color(0xFF75521A)),
  ),
  Room(
    key: RoomKey.phantom,
    title: 'Phantom Memory',
    subtitle: 'Analyze and brainstorm',
    mark: RoomMark.phantom,
    tile: TileGradient(Color(0xFF7D4ECD), Color(0xFF472585)),
  ),
];

/// One room out of the table. Throws rather than returns null: a key with
/// no entry is a typo, not a state.
Room roomFor(RoomKey key) => rooms.firstWhere((r) => r.key == key);
