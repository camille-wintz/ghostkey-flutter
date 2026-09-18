import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/words.dart';
import '../../ds/tokens.dart';
import '../../poltergeist/providers.dart';
import '../../poltergeist/tasks_notifier.dart';
import '../../poltergeist/time.dart';
import '../../server/providers.dart';
import '../../ui/room_subtitle.dart';
import '../../ui/room_title_bar.dart';
import '../project/project_root.dart';
import 'poltergeist_tabs.dart';

/// The room's chrome, named for the open page: Today, Words and Tasks under
/// their own names with the page's one figure beneath; the board under the
/// book's name, the way Apparition wears it, because the board IS the book's
/// chapters laid out.
class PoltergeistHeader extends ConsumerWidget {
  const PoltergeistHeader({super.key, required this.tab});
  final PoltergeistTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ProjectScope.of(context);
    void back() => Navigator.of(context).pop();

    return switch (tab) {
      PoltergeistTab.dashboard => RoomTitleBar(
          title: 'Today',
          subtitle: RoomSubtitle(todayLabel(DateTime.now())),
          onBack: back,
        ),
      PoltergeistTab.words => RoomTitleBar(
          title: 'Words',
          subtitle: RoomSubtitle(_wordsLine(ref, projectId)),
          onBack: back,
        ),
      PoltergeistTab.tasks => RoomTitleBar(
          title: 'Tasks',
          subtitle: RoomSubtitle(_tasksLine(ref, projectId)),
          onBack: back,
        ),
      PoltergeistTab.cats => RoomTitleBar(
          title: 'Cats',
          subtitle: RoomSubtitle(_catsLine(ref)),
          onBack: back,
        ),
      PoltergeistTab.plan => RoomTitleBar(
          title: ref.watch(projectProvider(projectId)).value?.project.displayTitle ?? 'Project',
          subtitle: _PlanSubtitle(projectId: projectId),
          onBack: back,
        ),
    };
  }

  String _catsLine(WidgetRef ref) {
    final cats = ref.watch(catsProvider).value;
    if (cats == null) return '—';
    return cats.isEmpty ? 'None yet' : '${cats.length} ${cats.length == 1 ? 'cat' : 'cats'}';
  }

  String _wordsLine(WidgetRef ref, String projectId) {
    final days = ref.watch(wordStatsProvider(projectId)).value;
    if (days == null) return '—';
    return '${formatWords(days.isNotEmpty ? days.last.total : 0)} in the manuscript';
  }

  String _tasksLine(WidgetRef ref, String projectId) {
    final state = ref.watch(tasksProvider(projectId));
    if (!state.hasValue) return state.hasError ? '—' : 'Loading…';
    final open = openTasks(state.value!.tasks).length;
    final done = doneTasks(state.value!.tasks).length;
    return open == 0 ? 'All clear' : '$open open · $done done';
  }
}

/// The manuscript's words — or, while the board holds itself against the
/// manuscript, that it is.
class _PlanSubtitle extends ConsumerWidget {
  const _PlanSubtitle({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(planBoardProvider(projectId)).isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 9, height: 9, child: CircularProgressIndicator(strokeWidth: 1.5, color: Ds.accent)),
          const SizedBox(width: 6),
          const RoomSubtitle('Checking'),
        ],
      );
    }
    final words = ref.watch(projectWordCountProvider(projectId)).value;
    return RoomSubtitle(words == null ? '—' : '${formatWords(words)} words');
  }
}
