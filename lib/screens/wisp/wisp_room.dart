import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/capability.dart';
import '../../access/plans.dart';
import '../../ds/tokens.dart';
import '../../rooms/rooms.dart';
import '../../server/providers.dart';
import '../../ui/room_title_bar.dart';
import '../../ui/state_screen.dart';
import '../../wisp/providers.dart';
import '../project/project_root.dart';
import '../../wisp/pages.dart';
import 'wisp_page_screen.dart';
import 'wisp_task_row.dart';

/// The room once it has arrived: the book in the bar, and every task as a
/// row — the list IS the room, as Veil's roster is. A task opens as a page
/// pushed on top.
class WispRoom extends ConsumerWidget {
  const WispRoom({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ProjectScope.of(context);
    final room = roomFor(RoomKey.wisp);
    void back() => Navigator.of(context).pop();

    final gate = ref.watch(capabilityProvider(room.capability));
    if (!gate.granted) {
      final plan = gate.requiredPlan != null ? planName(gate.requiredPlan!) : 'a higher plan';
      return StateScreen(message: 'Wisp is part of $plan.', actionLabel: 'Back to project', onAction: back);
    }

    final bookTitle = ref.watch(projectProvider(projectId)).value?.project.displayTitle;
    final running = ref.watch(wispRunningTasksProvider(projectId));
    final questions = ref.watch(continuityQuestionsProvider(projectId)).length;

    void open(WispPage page) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WispPageScreen(page: page)));

    return Scaffold(
      backgroundColor: Ds.void_,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RoomTitleBar(title: bookTitle ?? 'Project', onBack: back),
            Expanded(
              child: RefreshIndicator(
                color: Ds.accent,
                backgroundColor: Ds.panel,
                onRefresh: () => ref.refresh(wispJobsProvider(projectId).future),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 40),
                  children: [
                    for (final page in WispPage.values)
                      WispTaskRow(
                        page: page,
                        status: switch (page) {
                          WispPage.continuity when questions > 0 =>
                            '$questions ${questions == 1 ? 'question' : 'questions'} waiting',
                          _ when running.contains(page) => 'Running…',
                          _ => null,
                        },
                        onOpen: () => open(page),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
