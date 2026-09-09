import 'package:flutter/foundation.dart';

import '../../server/dossiers/api.dart';
import '../../server/dto/bible.dart';
import '../../server/dto/jobs.dart';
import '../../server/errors.dart';
import '../../server/jobs/run_job.dart';

/// Long enough to cover the slow tail of a real dossier (usually seconds, a
/// dense entity minutes), short enough that a spinner is never the whole
/// screen. Running out of it stops the *watching*, never the job: the server
/// runs to its own 20-minute cap and caches what it writes, so reopening the
/// entity finds the finished dossier without paying for it twice.
const Duration _wait = Duration(minutes: 5);

/// A build that ran but left no dossier gets one more go, exactly as on the
/// desktop — the case it is written for is a start that attached to *another*
/// entity's run and so did none of this entity's work.
const int _attempts = 2;

/// Wire codes the `entity_dossier` job can finish with that it does not
/// author prose for. Everything else renders the job's own `error_detail`.
const Map<String, String> _jobErrors = {
  'no_mentions':
      'The manuscript never names this one, so there are no passages to read. It will fill in once they appear.',
};

/// One entity's dossier, built on demand — the RN `useEntityDossier`.
///
/// Opening an entity that has none starts the job and holds a spinner,
/// because a bible card carries no facts of its own — the dossier IS what an
/// author opened the name to read, so making them press a button first would
/// only ask them to confirm the thing they just asked for. A dossier that
/// already exists is a cache hit and costs nothing, which is what makes that
/// safe.
class EntityDossierState extends ChangeNotifier {
  EntityDossierState({
    required this.projectId,
    required this.entityKey,
    required this.probe,
    required this.canBuild,
    required this.onFresh,
  });

  final String projectId;
  final String entityKey;

  /// The cache-only read of every dossier the server holds.
  final Future<Map<String, Dossier>> Function() probe;

  /// Whether the plan lets a new one be written. Read when it matters, so a
  /// snapshot landing late is still honoured.
  final bool Function() canBuild;

  /// A build produced a fresh map — the caller drops its cached read.
  final void Function() onFresh;

  Dossier? dossier;

  /// True until the cache-only read settles. A missing key on an unprobed
  /// map means "not asked yet", not "no dossier" — building on that would
  /// pay for a dossier the server already holds.
  bool probing = true;
  bool building = false;

  /// What the job says it is doing, while it does it.
  String? progress;
  String? error;

  bool _alive = true;
  bool _attempted = false;

  /// Probe, then build on open once if nothing is cached and no error stands.
  Future<void> open() async {
    try {
      final map = await probe();
      if (!_alive) return;
      dossier = map[entityKey];
    } catch (_) {
      // A map that failed to load is a build away from existing anyway.
    }
    if (!_alive) return;
    probing = false;
    notifyListeners();
    if (!_attempted && dossier == null && error == null && canBuild()) {
      _attempted = true;
      await build();
    }
  }

  /// Build this entity's dossier: the retry after a failure, and the update
  /// for a stale one (`force` re-reads the manuscript rather than trusting
  /// the cache's own verdict).
  Future<void> build({bool force = false}) async {
    building = true;
    progress = null;
    error = null;
    notifyListeners();
    try {
      for (var attempt = 0; attempt < _attempts; attempt++) {
        final outcome = await runJobToCompletion(
          projectId,
          'entity_dossier',
          {'key': entityKey, 'force': force},
          JobWatch(
            timeout: _wait,
            isAlive: () => _alive,
            onSnapshot: (JobSnapshot job) {
              if (!_alive) return;
              progress = job.progress?.label;
              notifyListeners();
            },
          ),
        );
        if (!_alive) return;

        switch (outcome) {
          case JobAbandoned():
            return;
          case JobTimedOut():
            error = 'This one is taking a while. The server is still writing it — come back in a minute.';
            return;
          case JobFinished(:final job):
            if (job?.status == JobStatus.error) {
              error = job!.errorDetail ?? _jobErrors[job.error ?? ''] ?? 'The dossier failed.';
              return;
            }
            if (job?.status == JobStatus.cancelled) {
              error = 'The dossier was cancelled.';
              return;
            }
        }

        final fresh = await getDossiers(projectId);
        if (!_alive) return;
        onFresh();
        final found = fresh[entityKey];
        if (found != null) {
          dossier = found;
          return;
        }
      }
      // Two runs, still nothing filed under this key.
      error = 'The dossier came back empty. Try again.';
    } catch (e) {
      if (_alive) error = messageFor(e);
    } finally {
      if (_alive) {
        building = false;
        progress = null;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    // A build outlives no view: the sheet closing stops the poll, and nothing
    // sets state on an object nobody is holding.
    _alive = false;
    super.dispose();
  }
}
