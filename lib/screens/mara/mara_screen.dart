import 'package:flutter/material.dart';

import '../../rooms/rooms.dart';
import '../project/room_entering.dart';
import 'mara_room.dart';

/// Mara: plotting — the outline in prose, the beats on a board, and the
/// chapters either becomes. One page at a time, from a list, as Wisp.
class MaraScreen extends StatelessWidget {
  const MaraScreen({super.key});
  static const route = '/mara';

  @override
  Widget build(BuildContext context) => Entered(
        room: roomFor(RoomKey.mara),
        builder: (context) => const MaraRoom(),
      );
}
