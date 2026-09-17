import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../server/dto/jobs.dart';
import '../../server/dto/plan.dart';
import '../../server/jobs/api.dart';
import '../../server/plan/api.dart';

// The chat Review's server reads: what a turn opened, read on demand. All
// autoDispose — the review is a page the author opens and leaves.

/// An edit pass's address: the document id, or `outline`.
typedef SubjectKey = ({String projectId, String subject});

/// How often a running pass is asked about. The phone has no job socket.
const Duration _passPoll = Duration(seconds: 2);

final storyMapsProvider = FutureProvider.autoDispose.family<List<StoryMap>, String>(
  (ref, projectId) => listStoryMaps(projectId),
);

final authoredOutlineProvider = FutureProvider.autoDispose.family<AuthoredOutline, String>(
  (ref, projectId) => getAuthoredOutline(projectId),
);

/// The newest `edit_pass` row on a subject, or null. Re-asks while it runs,
/// so the page moves from progress to notes by itself.
final editPassJobProvider = FutureProvider.autoDispose.family<JobSnapshot?, SubjectKey>((ref, key) async {
  final jobs = await listJobs(key.projectId);
  final job = jobs.where((j) => j.kind == 'edit_pass' && j.subject == key.subject).firstOrNull;
  if (job != null && job.isRunning) {
    final poll = Timer(_passPoll, ref.invalidateSelf);
    ref.onDispose(poll.cancel);
  }
  return job;
});
