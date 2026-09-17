import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/jobs.dart';
import '../server/dto/wisp.dart';
import '../server/errors.dart';
import '../server/jobs/api.dart';
import '../server/jobs/run_job.dart';
import '../server/providers.dart';
import 'providers.dart';

/// Which of Wisp's runs: its job kind, and the subject its running slot is
/// keyed on (the analysis, for `book_analysis`; none otherwise).
typedef WispRunKey = ({String projectId, String kind, String? subject});

WispRunKey analysisRunKey(String projectId, AnalysisId analysis) =>
    (projectId: projectId, kind: 'book_analysis', subject: analysis.wire);

WispRunKey outlineRunKey(String projectId) => (projectId: projectId, kind: 'reverse_outline', subject: null);

WispRunKey continuityRunKey(String projectId) => (projectId: projectId, kind: 'continuity', subject: null);

/// Each kind's runtime cap, server-side. Waiting that long is the honest
/// choice; running out stops the watching, never the job.
Duration _waitFor(String kind) => switch (kind) {
      'continuity' => const Duration(hours: 3),
      'book_analysis' => const Duration(minutes: 90),
      _ => const Duration(hours: 1),
    };

class WispRunState {
  const WispRunState({this.running = false, this.progress, this.length, this.error});
  final bool running;

  /// What the job says it is doing, while it does it.
  final JobProgress? progress;

  /// The reverse outline's length this run is making — null when the run was
  /// found already going, since a snapshot does not say.
  final OutlineLength? length;

  /// Why the last run did not finish, in the author's words.
  final String? error;
}

/// One of Wisp's runs for a project: start, attach and settle, and refresh
/// the page's read when it lands.
///
/// Opening a page attaches to a run already going on the server — started on
/// the desk, or before the author left the page — so the page shows the run
/// rather than offering to start a second one.
class WispRun extends Notifier<WispRunState> {
  WispRun(this.key);
  final WispRunKey key;

  @override
  WispRunState build() {
    Future.microtask(_attach);
    return const WispRunState();
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

  /// Start a run. `params` are the kind's own (`analysis`, `length`, `force`).
  Future<void> start(Map<String, dynamic> params, {OutlineLength? length}) async {
    if (state.running) return;
    await _watch(
      () => runJobToCompletion(key.projectId, key.kind, params, _watcher(), subject: key.subject),
      length,
    );
  }

  JobWatch _watcher() => JobWatch(
        timeout: _waitFor(key.kind),
        isAlive: () => ref.mounted,
        onSnapshot: (job) {
          if (ref.mounted) state = WispRunState(running: true, progress: job.progress, length: state.length);
        },
      );

  Future<void> _watch(Future<JobOutcome> Function() run, OutlineLength? length) async {
    state = WispRunState(running: true, length: length);
    try {
      final outcome = await run();
      if (!ref.mounted) return;
      switch (outcome) {
        case JobAbandoned():
          return;
        case JobTimedOut():
          state = const WispRunState(
            error: 'The run is still going on the server. Come back in a while and it will be here.',
          );
          return;
        case JobFinished(:final job):
          state = switch (job?.status) {
            JobStatus.error => WispRunState(error: job?.errorDetail ?? "The run didn't finish. Run it again."),
            JobStatus.cancelled => const WispRunState(error: 'The run was cancelled.'),
            _ => const WispRunState(),
          };
      }
      _refresh();
    } catch (e) {
      if (ref.mounted) state = WispRunState(error: messageFor(e));
    }
  }

  void _refresh() {
    ref.invalidate(wispJobsProvider(key.projectId));
    ref.invalidate(quotaProvider);
    switch (key.kind) {
      case 'book_analysis':
        final analysis = AnalysisId.values.where((a) => a.wire == key.subject).firstOrNull;
        if (analysis != null) ref.invalidate(analysisProvider((projectId: key.projectId, analysis: analysis)));
      case 'reverse_outline':
        ref.invalidate(outlineProvider(key.projectId));
      case 'continuity':
        ref.invalidate(continuityProvider(key.projectId));
    }
  }

  void dismissError() {
    if (!state.running) state = const WispRunState();
  }
}

final wispRunProvider = NotifierProvider.autoDispose.family<WispRun, WispRunState, WispRunKey>(WispRun.new);
