import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/capability.dart';
import '../../access/plans.dart';
import '../../ds/tokens.dart';
import '../../mara/pages.dart';
import '../../mara/providers.dart';
import '../../rooms/rooms.dart';
import '../../server/providers.dart';
import '../../ui/page_row.dart';
import '../../ui/room_title_bar.dart';
import '../../ui/state_screen.dart';
import '../project/project_root.dart';
import 'mara_page_screen.dart';

/// The room once it has arrived: the book in the bar, and the three pages as
/// rows. A page opens pushed on top.
class MaraRoom extends ConsumerWidget {
  const MaraRoom({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ProjectScope.of(context);
    final room = roomFor(RoomKey.mara);
    void back() => Navigator.of(context).pop();

    final gate = ref.watch(capabilityProvider(room.capability));
    if (!gate.granted) {
      final plan = gate.requiredPlan != null ? planName(gate.requiredPlan!) : 'a higher plan';
      return StateScreen(message: 'Mara is part of $plan.', actionLabel: 'Back to project', onAction: back);
    }

    final bookTitle = ref.watch(projectProvider(projectId)).value?.project.displayTitle;
    final outline = ref.watch(authoredOutlineProvider(projectId)).value;

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
                onRefresh: () => ref.refresh(authoredOutlineProvider(projectId).future),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 40),
                  children: [
                    for (final page in MaraPage.values)
                      PageRow(
                        icon: page.icon,
                        label: page.label,
                        description: page.description,
                        status: switch (page) {
                          MaraPage.chapters when outline?.changeset != null => 'Changes proposed — review them',
                          MaraPage.chapters when outline?.chapters.isNotEmpty ?? false => 'Chapters proposed — review them',
                          _ => null,
                        },
                        onOpen: () => openMaraPage(context, page),
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
