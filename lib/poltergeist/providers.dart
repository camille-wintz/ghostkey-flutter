import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/poltergeist.dart';
import '../server/dto/rewards.dart';
import '../server/poltergeist/api.dart';
import '../server/rewards/api.dart';
import 'ledger.dart';
import 'plan_board.dart';
import 'tasks_notifier.dart';

// The room's own reads and the two notifiers behind its edits. All
// auto-dispose: the room's shell watches each one for as long as the room is
// open, so tabs share one fetch and re-entering the room reads fresh.

/// The daily words series, oldest first, for the ledger window.
final wordStatsProvider = FutureProvider.autoDispose.family<List<WordStatsDay>, String>(
  (ref, projectId) => getProjectWordStats(projectId, days: ledgerDays),
);

/// The ticked days over the ledger's window and the week's standing. Same
/// window and offset as the word stats, so the two line up day for day.
final rewardsProvider = FutureProvider.autoDispose.family<Rewards, String>(
  (ref, projectId) => getProjectRewards(projectId, days: ledgerDays),
);

/// Every cat the author has, newest first. Per account, not per book.
final catsProvider = FutureProvider.autoDispose<List<Cat>>((ref) => listMyCats());

final tasksProvider = AsyncNotifierProvider.autoDispose.family<TasksNotifier, TasksState, String>(TasksNotifier.new);

final planBoardProvider =
    AsyncNotifierProvider.autoDispose.family<PlanBoardNotifier, PlanBoardState, String>(PlanBoardNotifier.new);

/// Read-only open-task count for the tab badge and the summary line.
final openTaskCountProvider = Provider.autoDispose.family<int, String>(
  (ref, projectId) => openTasks(ref.watch(tasksProvider(projectId)).value?.tasks).length,
);
