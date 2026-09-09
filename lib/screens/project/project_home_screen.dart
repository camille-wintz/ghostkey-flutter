import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../access/capability.dart';
import '../../access/plans.dart';
import '../../core/dates.dart';
import '../../ds/tokens.dart';
import '../../rooms/rooms.dart';
import '../../server/dto/billing.dart';
import '../../server/projects/covers.dart';
import '../../server/providers.dart';
import '../../store/active_project.dart';
import '../../ui/notice_modal.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';
import 'project_backdrop.dart';
import 'project_cover.dart';
import 'project_root.dart';
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
    final title = project?.displayTitle ?? 'Project';
    final cover = project != null ? projectCoverUrl(project, data?.assets ?? const []) : null;
    final backdrop = project != null ? projectBackdropUrl(project) : null;
    final edited = project != null ? formatShortDate(project.updatedAt) : '';

    void goHome() => ref.read(activeProjectProvider.notifier).close();

    return Scaffold(
      backgroundColor: Ds.void_,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ProjectBackdrop(backdropUrl: backdrop),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Press(
                        onPressed: goHome,
                        semanticLabel: 'Back to Home',
                        builder: (context, pressed) => Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: pressed ? Ds.veil : const Color(0x00000000),
                            borderRadius: BorderRadius.circular(DsGeom.radius),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.chevronLeft, size: 17, color: Ds.mid),
                              const SizedBox(width: 4),
                              UiText('Home', color: Ds.mid),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: RepaintBoundary(
                    child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 14, bottom: 30),
                          child: Center(child: ProjectCover(coverUrl: cover, title: title)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Amber means attention, and what this row is drawing
                            // attention to is which of an author's books they are inside.
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Ds.attention,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Ds.attention, blurRadius: 10)],
                              ),
                            ),
                            const SizedBox(width: 9),
                            Text(
                              'CURRENT PROJECT',
                              style: DsStyle.ui(DsText.eyebrow, color: Ds.mid, weight: FontWeight.w600, tracking: 11 * 0.32),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        Text(
                          title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: DsStyle.prose(const DsStep(30, 33), weight: FontWeight.w600).copyWith(letterSpacing: -0.15),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          project?.author.isNotEmpty == true ? project!.author : 'Unassigned author',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: DsStyle.ui(const DsStep(19, 22), color: Ds.soft),
                        ),
                        if (edited.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Center(child: _Chip('Last edited $edited')),
                          ),
                        const SizedBox(height: 30),
                        for (final room in rooms)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _RoomEntry(room: room, access: access),
                          ),
                      ],
                    ),
                  ),
                  ),
                ),
              ],
            ),
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

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Ds.veil,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: UiText(text, step: DsText.ui, color: Ds.soft),
      );
}
