import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/capability.dart';
import '../../access/plans.dart';
import '../../ds/tokens.dart';
import '../../rooms/rooms.dart';
import '../../server/dto/billing.dart';
import '../../server/projects/covers.dart';
import '../../server/providers.dart';
import '../../store/active_project.dart';
import '../../ui/notice_modal.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';
import 'project_root.dart';
import 'project_stage.dart';
import '../onboarding/intents.dart';
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
    // At most one room is pointed at, and only on the arrival the first-run
    // flow made. `markFor` returns null for an intent this phone answers in the
    // chat rather than in a room.
    final marked = markFor(ref.watch(activeProjectProvider.select((p) => p.mark)));
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
              child: _RoomEntry(
                room: room,
                access: access,
                marked: marked?.room == room.key,
                mark: marked,
                onMarkDismissed: () => ref.read(activeProjectProvider.notifier).clearMark(),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoomEntry extends StatelessWidget {
  const _RoomEntry({
    required this.room,
    required this.access,
    this.marked = false,
    this.mark,
    this.onMarkDismissed,
  });
  final Room room;
  final AccessSnapshot? access;

  /// Whether the first-run flow pointed at this room. At most one row is.
  final bool marked;
  final IntentOption? mark;
  final VoidCallback? onMarkDismissed;

  @override
  Widget build(BuildContext context) {
    final state = capabilityFrom(access, room.capability);
    final row = RoomRow(
      room: room,
      granted: state.granted,
      requiredPlan: state.requiredPlan,
      onOpen: () => state.granted
          ? Navigator.of(context).pushNamed(routeForRoom(room.key))
          : _explainLock(context, room, state.requiredPlan),
    );
    if (!marked || mark == null) return row;

    // The phone's coachmark is a ring and a note under the row, not a floating
    // panel: the rooms are a list, there is one thing to say, and a popover
    // over a 64px row on a phone covers the thing it is pointing at.
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(color: Ds.accent),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row,
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: UiText(mark!.markBody, color: Ds.soft),
          ),
          Press(
            onPressed: onMarkDismissed,
            semanticLabel: 'Got it',
            builder: (context, pressed) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Text('Got it', style: DsStyle.eyebrow(color: pressed ? Ds.hi : Ds.mid)),
            ),
          ),
        ],
      ),
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
