import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../access/capability.dart';
import '../../access/plans.dart';
import '../../ds/tokens.dart';
import '../../rooms/rooms.dart';
import '../../server/chat/api.dart';
import '../../ui/state_screen.dart';
import '../project/project_root.dart';
import '../project/room_entering.dart';
import 'chat_screen.dart';
import 'chat_sessions_drawer.dart';

/// The PhantomMemory room: the chat behind a sessions drawer — the same
/// idiom as Apparition, "hamburger opens the room's list". The room gates
/// itself on `room.phantom` again (the home already did) for the
/// downgrade-while-open case, the desktop's RoomGate behaviour.
///
/// Built after the push lands rather than during it (`Entered`): the turn
/// owner, the drawer and the session list all mount at once, and doing that
/// inside the entry animation reads as a freeze.
class PhantomScreen extends StatelessWidget {
  const PhantomScreen({super.key});
  static const route = '/phantom';

  @override
  Widget build(BuildContext context) => Entered(
        room: roomFor(RoomKey.phantom),
        builder: (context) => _PhantomRoom(projectId: ProjectScope.of(context)),
      );
}

class _PhantomRoom extends ConsumerStatefulWidget {
  const _PhantomRoom({required this.projectId});
  final String projectId;

  @override
  ConsumerState<_PhantomRoom> createState() => _PhantomRoomState();
}

class _PhantomRoomState extends ConsumerState<_PhantomRoom> {
  @override
  void initState() {
    super.initState();
    // Once per room open, fire and forget — the learning half of a memory
    // that is otherwise viewed and edited on the desktop. The server gates
    // on staleness and answers without a model call when nothing is due.
    if (ref.read(capabilityProvider(roomFor(RoomKey.phantom).capability)).granted) {
      postReflect(widget.projectId).catchError((Object e) {
        if (kDebugMode) debugPrint('[PhantomScreen] reflect failed: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = roomFor(RoomKey.phantom);
    final access = ref.watch(capabilityProvider(room.capability));

    if (!access.granted) {
      final plan = access.requiredPlan != null ? planName(access.requiredPlan!) : 'a higher plan';
      return StateScreen(
        icon: LucideIcons.lock,
        message: '${room.title} is part of $plan',
        detail: 'Your plan follows your account rather than this phone, and Account always says which one you are on.',
        actionLabel: 'Back to project',
        onAction: () => Navigator.of(context).pop(),
      );
    }

    return Scaffold(
      backgroundColor: Ds.void_,
      drawerEdgeDragWidth: 60,
      drawerScrimColor: const Color(0x80000000),
      drawer: Drawer(
        width: MediaQuery.sizeOf(context).width * 0.87,
        backgroundColor: Ds.panel,
        shape: const RoundedRectangleBorder(),
        child: ChatSessionsDrawer(projectId: widget.projectId),
      ),
      body: ChatScreen(projectId: widget.projectId),
    );
  }
}
