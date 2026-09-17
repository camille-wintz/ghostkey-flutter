import 'package:flutter/material.dart';

import '../../rooms/rooms.dart';
import '../project/room_entering.dart';
import 'wisp_room.dart';

/// Wisp: editing — line edits chapter by chapter, the continuity check, the
/// three analyses of the whole, and the reverse outline. One page at a time,
/// picked from the title the way the chat picks a conversation.
class WispScreen extends StatelessWidget {
  const WispScreen({super.key});
  static const route = '/wisp';

  @override
  Widget build(BuildContext context) => Entered(
        room: roomFor(RoomKey.wisp),
        builder: (context) => const WispRoom(),
      );
}
