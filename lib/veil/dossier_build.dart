import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../access/capability.dart';
import '../server/dto/jobs.dart';
import '../server/dto/projects.dart';
import '../server/errors.dart';
import '../server/jobs/run_job.dart';
import '../server/providers.dart';
import 'providers.dart';

/// Long enough to cover the slow tail of a real dossier (usually seconds, a
/// dense entity minutes), short enough that a spinner is never the whole
/// screen. Running out of it stops the *watching*, never the job: the server
/// runs to its own 20-minute cap and caches what it writes, so reopening the
/// entity finds the finished dossier without paying for it twice.
const Duration _wait = Duration(minutes: 5);

/// A build that ran but left no dossier gets one more go, exactly as on the
/// desktop — the case it is written for is a start that attached to
/// *another* entity's run (one slot per kind) and so did none of this
/// entity's work.
const int _attempts = 2;

/// Wire codes the `entity_dossier` job can finish with that it authors no
/// prose for. Everything else renders the job's own `error_detail`.
const Map<String, String> _jobErrors = {
  'no_mentions':
      'The manuscript never names this one, so there are no passages to read. It will fill in once they appear.',
};

/// The capability that governs *building* a dossier. An existing one renders
/// on any plan.
const String dossierCapability = 'mara.entity_dossier';

typedef DossierTarget = ({String projectId, String key});

class DossierBuildState {
  const DossierBuildState({this.building = false, this.progress, this.error});
  final bool building;
  final String? progress;
  final String? error;
}

/// One entity's dossier build. Opening an entity that has none starts the
/// job and holds a loader, because a bible card carries no facts of its own —
/// the dossier IS what the author opened the name to read. A dossier that
/// exists is a cache hit and costs nothing, which is what makes that safe.
///
/// Scoped to one entity page: the page popping disposes it, so the
/// build-on-open latch is per open, as the desktop's route remount makes it.
class DossierBuild extends Notifier<DossierBuildState> {
  DossierBuild(this.target);
  final DossierTarget target;
  bool _attempted = false;

  @override
  DossierBuildState build() => const DossierBuildState();

  /// The build-on-open: once, after the cache probe settles with nothing
  /// filed under this key and no error, run what the author would otherwise
  /// be asked to press. Never retries a failure and never touches a stale
  /// dossier — one autosave mid-run marks a good dossier stale, and a retry
  /// would spend a second model call.
  Future<void> buildOnOpen() async {
    if (_attempted) return;
    _attempted = true;
    try {
      final dossiers = await ref.read(dossiersProvider(target.projectId).future);
      if (!ref.mounted || dossiers.containsKey(target.key)) return;
      if (!await _canBuild()) return;
    } catch (e) {
      // A probe that failed is a build away from existing anyway; say so on
      // the page rather than let the error escape the microtask.
      if (ref.mounted) state = DossierBuildState(error: messageFor(e));
      return;
    }
    if (ref.mounted && !state.building && state.error == null) await start();
  }

  /// The server's own checks, asked first so a page that may not build is
  /// told that instead of shown a run that 403s.
  Future<bool> _canBuild() async {
    if (!ref.read(capabilityProvider(dossierCapability)).granted) return false;
    final bible = await ref.read(bibleProvider(target.projectId).future);
    if (!ref.mounted) return false;
    final entity = bible.entities.where((e) => e.key == target.key).firstOrNull;
    if (entity == null || entity.mentionCount == 0) return false;
    final project = await ref.read(projectProvider(target.projectId).future);
    return ref.mounted && chaptersInTree(project.chapters).isNotEmpty;
  }

  /// Build this entity's dossier: the retry after a failure, the update for
  /// a stale one, and — with `force` — a re-read of the manuscript rather
  /// than trusting the cache's own verdict.
  Future<void> start({bool force = false}) async {
    if (state.building) return;
    state = const DossierBuildState(building: true);
    try {
      for (var attempt = 0; attempt < _attempts; attempt++) {
        final outcome = await runJobToCompletion(
          target.projectId,
          'entity_dossier',
          {'key': target.key, if (force) 'force': true},
          JobWatch(
            timeout: _wait,
            isAlive: () => ref.mounted,
            onSnapshot: (job) {
              if (ref.mounted) state = DossierBuildState(building: true, progress: job.progress?.label);
            },
          ),
        );
        if (!ref.mounted) return;

        switch (outcome) {
          case JobAbandoned():
            return;
          case JobTimedOut():
            state = const DossierBuildState(
              error: 'This one is taking a while. The server is still writing it — come back in a minute.',
            );
            return;
          case JobFinished(:final job):
            if (job?.status == JobStatus.error) {
              state = DossierBuildState(
                error: job?.errorDetail ?? _jobErrors[job?.error ?? ''] ?? 'The dossier failed.',
              );
              return;
            }
            if (job?.status == JobStatus.cancelled) {
              state = const DossierBuildState(error: 'The dossier was cancelled.');
              return;
            }
        }

        final fresh = await ref.refresh(dossiersProvider(target.projectId).future);
        if (!ref.mounted) return;
        if (fresh.containsKey(target.key)) {
          state = const DossierBuildState();
          return;
        }
      }
      // Two runs, still nothing filed under this key.
      state = const DossierBuildState(error: 'The dossier came back empty. Try again.');
    } catch (e) {
      if (ref.mounted) state = DossierBuildState(error: messageFor(e));
    }
  }
}

final dossierBuildProvider = NotifierProvider.autoDispose.family<DossierBuild, DossierBuildState, DossierTarget>(
  DossierBuild.new,
);
