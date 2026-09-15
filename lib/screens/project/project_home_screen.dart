import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/capability.dart';
import '../../access/plans.dart';
import '../../rooms/rooms.dart';
import '../../server/dto/billing.dart';
import '../../server/projects/covers.dart';
import '../../server/providers.dart';
import '../../store/active_project.dart';
import '../../ui/notice_modal.dart';
import 'project_root.dart';
import 'project_stage.dart';
import 'room_row.dart';

/// The project home — the launcher's project page on a phone. The whole
/// screen is one statement about which book is open: its own cover lights the
/// backdrop, is held above the fold, and names itself before anything else
/// is offered. Then the rooms, as rows.
///
/// One way out, not two: the header's "Home" closes the project, and the
/// footer link that said the same thing at the other end of the scroll is
/// gone — a second control for the one action only asks which one is meant.
class ProjectHomeScreen extends ConsumerWidget {
  const ProjectHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ProjectScope.of(context);
    final data = ref.watch(projectProvider(projectId)).value;
    final access = ref.watch(accessProvider).value;
    final project = data?.project;
    final cover = project != null ? projectCoverUrl(project, data?.assets ?? const []) : null;

    return ProjectStage(
      project: project,
      coverUrl: cover,
      onHome: () => ref.read(activeProjectProvider.notifier).close(),
      below: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final room in rooms)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _RoomEntry(room: room, access: access),
            ),
        ],
      ),
    );
  }
}

class _RoomEntry extends StatelessWidget {
  const _RoomEntry({required this.room, required this.access});
  final Room room;
  final AccessSnapshot? access;

  @override
  Widget build(BuildContext context) {
    final state = capabilityFrom(access, room.capability);
    return RoomRow(
      room: room,
      granted: state.granted,
      requiredPlan: state.requiredPlan,
      onOpen: () => state.granted
          ? Navigator.of(context).pushNamed(routeForRoom(room.key))
          : _explainLock(context, room, state.requiredPlan),
    );
  }
}

/// What a locked room says when tapped: which plan opens it, and nothing to
/// buy — mobile reports and never sells.
void _explainLock(BuildContext context, Room room, Plan? requiredPlan) {
  final plan = requiredPlan != null ? planName(requiredPlan) : null;
  showNoticeModal(
    context,
    eyebrow: 'Not on your plan',
    title: plan != null ? '${room.title} is part of $plan' : '${room.title} is part of a higher plan',
    action: 'Got it',
    children: [
      NoticeText(
        plan != null
            ? '$plan and the plans above it open ${room.title}. Your plan follows your account rather than this phone, and Account always says which one you are on.'
            : 'A higher plan opens ${room.title}. Your plan follows your account rather than this phone, and Account always says which one you are on.',
      ),
    ],
  );
}
