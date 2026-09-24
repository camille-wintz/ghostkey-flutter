import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/quota_refusals.dart';
import '../dto/jobs.dart';
import '../errors.dart';
import 'api.dart';
import 'run_job.dart';

/// Which run: its job kind, and the subject its running slot is keyed on
/// (null for a kind with one slot per project).
typedef JobRunKey = ({String projectId, String kind, String? subject});

class JobRunState {
  const JobRunState({this.running = false, this.progress, this.tag, this.error});
  final bool running;

  /// What the job says it is doing, while it does it.
  final JobProgress? progress;

  /// What the caller said this run makes when it started it (a length, a
  /// board). Null when the run was found already going: a snapshot does not
  /// say.
  final Object? tag;

  /// Why the last run did not finish, in the author's words.
  final String? error;
}

/// One server job, watched from a page: start it, attach to one already
/// going, settle it, and say what its landing makes stale. The loop, the
/// deadline, the quota report and the wording of an unfinished run live
/// here once; a subclass names only its patience and what to re-read.
///
/// Opening a page attaches to a run already going on the server — started on
/// the desk, or before the author left the page — so the page shows the run
/// rather than offering to start a second one.
abstract class JobRun extends Notifier<JobRunState> {
  JobRun(this.key);
  final JobRunKey key;

  /// How long to keep watching — the kind's runtime cap, server-side.
  /// Running out stops the watching, never the job.
  Duration get patience => const Duration(hours: 1);

  /// What a landed run (finished, failed or cancelled) makes stale.
  void onLanded();

  @override
  JobRunState build() {
    Future.microtask(_attach);
    return const JobRunState();
  }

  Future<void> _attach() async {
    try {
      final jobs = await listJobs(key.projectId);
      final running = jobs.where((j) => j.kind == key.kind && j.subject == key.subject && j.isRunning).firstOrNull;
      if (running == null || !ref.mounted || state.running) return;
      await _watch(() async => awaitJob(key.projectId, running, _watcher()), null);
    } catch (_) {
      // Not finding a run to attach to is the page's ordinary state.
    }
  }

  /// Start a run with the kind's own `params`.
  Future<void> start(Map<String, dynamic> params, {Object? tag}) async {
    if (state.running) return;
    await _watch(
      () => runJobToCompletion(key.projectId, key.kind, params, _watcher(), subject: key.subject),
      tag,
    );
  }

  JobWatch _watcher() => JobWatch(
        timeout: patience,
        isAlive: () => ref.mounted,
        onSnapshot: (job) {
          if (ref.mounted) state = JobRunState(running: true, progress: job.progress, tag: state.tag);
        },
      );

  Future<void> _watch(Future<JobOutcome> Function() run, Object? tag) async {
    state = JobRunState(running: true, tag: tag);
    try {
      final outcome = await run();
      if (!ref.mounted) return;
      switch (outcome) {
        case JobAbandoned():
          return;
        case JobTimedOut():
          state = const JobRunState(
            error: 'The run is still going on the server. Come back in a while and it will be here.',
          );
          return;
        case JobFinished(:final job):
          state = switch (job?.status) {
            JobStatus.error => JobRunState(error: job?.errorDetail ?? "The run didn't finish. Run it again."),
            JobStatus.cancelled => const JobRunState(error: 'The run was cancelled.'),
            _ => const JobRunState(),
          };
      }
      onLanded();
    } catch (e) {
      if (!ref.mounted) return;
      state = reportQuotaRefusal(e) ? const JobRunState() : JobRunState(error: messageFor(e));
    }
  }

  void dismissError() {
    if (!state.running) state = const JobRunState();
  }
}
