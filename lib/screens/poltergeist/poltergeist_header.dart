import 'package:flutter/material.dart';

import '../project/room_header.dart';

/// The room's chrome: the way back to the project home and the room's name —
/// the shared [RoomHeader], so this room says it the way every other one does.
class PoltergeistHeader extends StatelessWidget {
  const PoltergeistHeader({super.key});

  @override
  Widget build(BuildContext context) => const RoomHeader(room: 'Poltergeist');
}
