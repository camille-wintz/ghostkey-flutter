import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../access/capability.dart';
import '../../access/plans.dart';
import '../../ds/tokens.dart';
import '../../rooms/rooms.dart';
import '../../server/dto/projects.dart';
import '../../server/errors.dart';
import '../../server/providers.dart';
import '../../ui/notice_modal.dart';
import '../../ui/state_screen.dart';
import '../../veil/providers.dart';
import '../../veil/world_bible_run.dart';
import '../project/project_root.dart';
import '../project/room_entering.dart';
import '../project/room_header.dart';
import 'veil_actions_sheet.dart';
import 'veil_roster.dart';
import 'veil_run_banner.dart';

/// The capability that governs running the extraction. Adding and reading by
/// hand are never gated here; the server gates them at basic anyway.
const String _generateCapability = 'mara.world_bible_generate';

/// Veil: the world bible, and only that. The roster IS the room — no drawer,
/// no landing page — because hiding the bible behind an icon is exactly what
/// buried it inside Mara on the desktop. One entity is a page pushed on top.
class VeilScreen extends StatelessWidget {
  const VeilScreen({super.key});
  static const route = '/veil';

  @override
  Widget build(BuildContext context) => Entered(
        room: roomFor(RoomKey.veil),
        builder: (context) => const _VeilRoom(),
      );
}

class _VeilRoom extends ConsumerWidget {
  const _VeilRoom();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ProjectScope.of(context);
    final room = roomFor(RoomKey.veil);
    void back() => Navigator.of(context).pop();

    // The downgrade-while-open case: the home locks the row, but a plan that
    // lapses with the room open is told here rather than shown a 403.
    final gate = ref.watch(capabilityProvider(room.capability));
    if (!gate.granted) {
      final plan = gate.requiredPlan != null ? planName(gate.requiredPlan!) : 'a higher plan';
      return StateScreen(message: 'Veil is part of $plan.', actionLabel: 'Back to project', onAction: back);
    }

    final bible = ref.watch(bibleProvider(projectId));
    final run = ref.watch(worldBibleRunProvider(projectId));
    final project = ref.watch(projectProvider(projectId)).value;
    final generate = ref.watch(capabilityProvider(_generateCapability));
    final hasChapters = project != null && chaptersInTree(project.chapters).isNotEmpty;

    // Access first, then the run — the order the server checks in startJob,
    // so an author who may not run this at all is told that.
    void start(bool force) {
      if (!generate.granted) {
        _explainLock(context, generate);
        return;
      }
      unawaited(ref.read(worldBibleRunProvider(projectId).notifier).start(force: force));
    }

    void openActions() => showVeilActions(
          context,
          hasExtraction: bible.value?.hasExtraction ?? false,
          hasChapters: hasChapters,
          locked: !generate.granted,
          run: run,
          onRun: start,
        );

    final Widget body;
    if (bible.hasValue) {
      body = VeilRoster(
        projectId: projectId,
        bible: bible.value!,
        hasChapters: hasChapters,
        running: run.running,
        onGenerate: () => start(false),
      );
    } else if (bible.isLoading) {
      body = const StateScreen(spinner: true, message: 'Checking for a saved bible…');
    } else {
      body = StateScreen(
        message: 'Could not load the world bible.',
        detail: messageFor(bible.error),
        actionLabel: 'Try Again',
        onAction: () => ref.invalidate(bibleProvider(projectId)),
        secondaryActionLabel: 'Back to project',
        onSecondaryAction: back,
      );
    }

    return Scaffold(
      backgroundColor: Ds.void_,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RoomHeader(
              room: 'Veil',
              trailing: bible.hasValue
                  ? RoomHeaderAction(
                      icon: LucideIcons.ellipsisVertical,
                      onPressed: openActions,
                      semanticLabel: 'More',
                    )
                  : null,
            ),
            if (run.running || run.error != null)
              VeilRunBanner(
                state: run,
                onDismiss: () => ref.read(worldBibleRunProvider(projectId).notifier).dismissError(),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// What a locked Generate says when tapped: which plan opens it, and nothing
/// to buy — mobile reports and never sells.
void _explainLock(BuildContext context, CapabilityState state) {
  final plan = state.requiredPlan != null ? planName(state.requiredPlan!) : null;
  final what = state.label ?? 'Generating the world bible';
  showNoticeModal(
    context,
    eyebrow: 'Not on your plan',
    title: plan != null ? '$what is part of $plan' : '$what is part of a higher plan',
    action: 'Got it',
    children: [
      NoticeText(
        plan != null
            ? '$plan and the plans above it can read the manuscript for its characters, places and terms. Reading a bible that already exists works on every plan.'
            : 'A higher plan can read the manuscript for its characters, places and terms. Reading a bible that already exists works on every plan.',
      ),
    ],
  );
}
