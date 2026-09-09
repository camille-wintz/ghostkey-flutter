import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/jobs.dart';
import '../server/errors.dart';
import '../server/jobs/run_job.dart';
import 'providers.dart';

/// The `world_bible` job's cap, server-side. Waiting that long is the
/// honest choice — the run is minutes on a real book and may first spawn an
/// `ai_outline` job — and running out stops the watching, never the job.
const Duration _wait = Duration(minutes: 90);

class WorldBibleRunState {
  const WorldBibleRunState({this.running = false, this.progress, this.error});
  final bool running;

  /// What the job says it is doing, while it does it.
  final String? progress;
  final String? error;
}

/// One run of the world-bible extraction for a project: Generate, Update
/// and Rebuild are the same job, `force` being the only difference. Knows
/// how to start, attach (a 409 is answered by joining the run already going)
/// and settle, and refreshes the two reads when it lands — a rebuild can
/// change keys, so the dossiers drop too.
///
/// Lives as long as the room: leaving Veil stops the watching, and the next
/// Update attaches to a run still going.
class WorldBibleRun extends Notifier<WorldBibleRunState> {
  WorldBibleRun(this.projectId);
  final String projectId;

  @override
  WorldBibleRunState build() => const WorldBibleRunState();

  Future<void> start({bool force = false}) async {
    if (state.running) return;
    state = const WorldBibleRunState(running: true);
    try {
      final outcome = await runJobToCompletion(
        projectId,
        'world_bible',
        {if (force) 'force': true},
        JobWatch(
          timeout: _wait,
          isAlive: () => ref.mounted,
          onSnapshot: (job) {
            if (ref.mounted) state = WorldBibleRunState(running: true, progress: job.progress?.label);
          },
        ),
      );
      if (!ref.mounted) return;
      switch (outcome) {
        case JobAbandoned():
          return;
        case JobTimedOut():
          state = const WorldBibleRunState(
            error: 'The run is still going on the server. Come back in a while and press Update to catch up.',
          );
          return;
        case JobFinished(:final job):
          state = switch (job?.status) {
            JobStatus.error => WorldBibleRunState(error: job?.errorDetail ?? 'The world bible run failed.'),
            JobStatus.cancelled => const WorldBibleRunState(error: 'The run was cancelled.'),
            _ => const WorldBibleRunState(),
          };
      }
      ref.invalidate(bibleProvider(projectId));
      ref.invalidate(dossiersProvider(projectId));
    } catch (e) {
      if (ref.mounted) state = WorldBibleRunState(error: messageFor(e));
    }
  }

  void dismissError() {
    if (!state.running) state = const WorldBibleRunState();
  }
}

final worldBibleRunProvider = NotifierProvider.autoDispose.family<WorldBibleRun, WorldBibleRunState, String>(
  WorldBibleRun.new,
);
