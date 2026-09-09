import '../dto/jobs.dart';
import '../errors.dart';
import 'api.dart';

// Watching a server-side job, for a client that has no socket. One owner for
// the loop, so the deadline, the dropped-poll rule and the abandon guard live
// in one place.

/// How often to ask. Fast enough that a progress line moves rather than
/// jumping from empty to done, slow enough that a long job is a couple of
/// dozen requests rather than hundreds.
const Duration _poll = Duration(milliseconds: 1500);

/// How a wait ended. `finished` is a terminal row — including `error` and
/// `cancelled`, which are outcomes the caller renders. `job` is null only when
/// a start refused with `job_running` found no run to attach to, which means
/// the artifact is fresh. `abandoned` is the caller going away mid-wait;
/// `timeout` is the job still running when patience ran out.
sealed class JobOutcome {
  const JobOutcome();
}

class JobFinished extends JobOutcome {
  const JobFinished(this.job);
  final JobSnapshot? job;
}

class JobAbandoned extends JobOutcome {
  const JobAbandoned();
}

class JobTimedOut extends JobOutcome {
  const JobTimedOut();
}

class JobWatch {
  const JobWatch({required this.timeout, this.onSnapshot, this.isAlive});

  /// Called with every snapshot the poll reads, for a progress line.
  final void Function(JobSnapshot job)? onSnapshot;

  /// False once the caller has gone: the loop stops asking about a job nobody
  /// is watching.
  final bool Function()? isAlive;

  /// Give up waiting after this long. The job is not cancelled.
  final Duration timeout;
}

/// Poll one job until it reaches a terminal state.
Future<JobOutcome> awaitJob(String projectId, JobSnapshot job, JobWatch watch) async {
  bool alive() => watch.isAlive?.call() ?? true;
  final deadline = DateTime.now().add(watch.timeout);

  var current = job;
  watch.onSnapshot?.call(current);

  while (current.isRunning) {
    if (!alive()) return const JobAbandoned();
    if (DateTime.now().isAfter(deadline)) return const JobTimedOut();
    await Future<void>.delayed(_poll);
    if (!alive()) return const JobAbandoned();
    try {
      current = await getJob(projectId, job.id);
    } catch (_) {
      // A dropped poll is not a failed job — it is running on the server
      // either way. Keep asking until the deadline.
      continue;
    }
    watch.onSnapshot?.call(current);
  }
  return JobFinished(current);
}

/// Start a job and watch it to the end. A 409 `job_running` is answered by
/// attaching to that run, never by reporting a failure; if it has already
/// finished in the gap, `JobFinished(null)`.
Future<JobOutcome> runJobToCompletion(
  String projectId,
  String kind,
  Map<String, dynamic> params,
  JobWatch watch,
) async {
  JobSnapshot job;
  try {
    job = await startJob(projectId, kind, params: params);
  } on ServerError catch (e) {
    if (e.code != 'job_running') rethrow;
    final running = (await listJobs(projectId)).where((j) => j.kind == kind && j.isRunning).firstOrNull;
    if (running == null) return const JobFinished(null);
    job = running;
  }
  return awaitJob(projectId, job, watch);
}
