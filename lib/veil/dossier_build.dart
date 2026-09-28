import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../access/quota_refusals.dart';
import '../server/dto/jobs.dart';
import '../server/errors.dart';
import '../server/jobs/run_job.dart';
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

/// One entity's dossier build. Nothing runs on open, as on the desk: an
/// empty card offers Fill from the book beside Create dossier, and every run
/// is one the author pressed — a model call is theirs to spend.
///
/// Scoped to one entity page: the page popping disposes it.
class DossierBuild extends Notifier<DossierBuildState> {
  DossierBuild(this.target);
  final DossierTarget target;

  @override
  DossierBuildState build() => const DossierBuildState();

  /// Build this entity's dossier: the retry after a failure, the update for
  /// a stale one, and — with `force` — a re-read of the manuscript rather
  /// than trusting the cache's own verdict.
  ///
  /// The job files its prose into the card's dossier text (`notes`) when that
  /// is empty; `fill` is the author asking it to replace what is there — the
  /// Refresh, after the page's warning. `portrait` asks a first fill to draw
  /// the card's portrait too (the server skips a card that has one, and a
  /// plan without drawing), as the desk's Fill does. Either way the card may have changed
  /// server-side, so a landing re-reads the bible as well as the dossiers.
  Future<void> start({bool force = false, bool fill = false, bool portrait = false}) async {
    if (state.building) return;
    state = const DossierBuildState(building: true);
    try {
      for (var attempt = 0; attempt < _attempts; attempt++) {
        final outcome = await runJobToCompletion(
          target.projectId,
          'entity_dossier',
          {'key': target.key, if (force) 'force': true, if (fill) 'fill': true, if (portrait) 'portrait': true},
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

        ref.invalidate(bibleProvider(target.projectId));
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
      if (!ref.mounted) return;
      state = reportQuotaRefusal(e) ? const DossierBuildState() : DossierBuildState(error: messageFor(e));
    }
  }
}

final dossierBuildProvider = NotifierProvider.autoDispose.family<DossierBuild, DossierBuildState, DossierTarget>(
  DossierBuild.new,
);
