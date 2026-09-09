import 'package:flutter/material.dart';

import '../../rooms/rooms.dart';
import '../project/room_entering.dart';
import 'poltergeist_shell.dart';

/// Poltergeist — the writer's back office: the dashboard, the words ledger,
/// the task list and the plan board, as four tabs under one header.
class PoltergeistScreen extends StatelessWidget {
  const PoltergeistScreen({super.key});
  static const route = '/poltergeist';

  @override
  Widget build(BuildContext context) => Entered(
        room: roomFor(RoomKey.poltergeist),
        builder: (context) => const PoltergeistShell(),
      );
}
