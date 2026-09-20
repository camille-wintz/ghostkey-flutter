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

/// THIS BOOK's daily series, oldest first — read for its manuscript size,
/// on the header and the dashboard's chapter band. The ledger itself reads
/// the account-wide twin below.
final wordStatsProvider = FutureProvider.autoDispose.family<List<WordStatsDay>, String>(
  (ref, projectId) => getProjectWordStats(projectId, days: ledgerDays),
);

/// The whole ledger: the window's daily writing across every live book, the
/// ticked days among them and the week's standing. Per account, not per
/// book — a day's writing is every book's words added up, and so is the
/// target it is measured against. Same window and offset as the word stats,
/// so the two line up day for day.
final rewardsProvider = FutureProvider.autoDispose<Rewards>((ref) => getMyRewards(days: ledgerDays));

/// Every cat the author has, newest first. Per account, not per book.
final catsProvider = FutureProvider.autoDispose<List<Cat>>((ref) => listMyCats());

/// Every cat there is to earn, as shapes only — what a shelf with nothing on
/// it yet can show. The same list for every author, so it never changes under
/// a session.
final catCatalogueProvider =
    FutureProvider.autoDispose<List<CatSilhouette>>((ref) => listCatCatalogue());

final tasksProvider = AsyncNotifierProvider.autoDispose.family<TasksNotifier, TasksState, String>(TasksNotifier.new);

final planBoardProvider =
    AsyncNotifierProvider.autoDispose.family<PlanBoardNotifier, PlanBoardState, String>(PlanBoardNotifier.new);

/// Read-only open-task count for the tab badge and the summary line.
final openTaskCountProvider = Provider.autoDispose.family<int, String>(
  (ref, projectId) => openTasks(ref.watch(tasksProvider(projectId)).value?.tasks).length,
);
