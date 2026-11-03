import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../server/chat/batches.dart';
import '../../server/dto/batch.dart';
import '../../server/dto/jobs.dart';
import '../../server/dto/media.dart';
import '../../server/jobs/api.dart';
import '../../server/media/api.dart';

// The chat Review's own server reads — the edit pass on a subject, and a
// picture a tool opened. The
// plan's reads (boards, the outline row) are Mara's (`mara/providers.dart`).
// All autoDispose — the review is a page the author opens and leaves.

/// An edit pass's address: the document id, or `outline`.
typedef SubjectKey = ({String projectId, String subject});

/// How often a running pass is asked about. The phone has no job socket.
const Duration _passPoll = Duration(seconds: 2);

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

/// A media item's address: the book it was opened from and the item id.
typedef MediaItemKey = ({String projectId, String itemId});

/// One library item, for a picture view — its bytes' series, asset and
/// caption, none of which the view itself carries.
final mediaItemProvider = FutureProvider.autoDispose.family<MediaItem, MediaItemKey>(
  (ref, key) async => (await getMediaItem(key.projectId, key.itemId)).item,
);

/// A batch's address.
typedef BatchKey = ({String projectId, String batchId});

/// How often a batch still going is asked about. The phone has no job socket.
const Duration _batchPoll = Duration(seconds: 4);

/// A batch as the server has it. Re-asks while it runs or its review does.
final batchProvider = FutureProvider.autoDispose.family<BatchPage, BatchKey>((ref, key) async {
  final page = await readBatch(key.projectId, key.batchId);
  if (page.live) {
    final poll = Timer(_batchPoll, ref.invalidateSelf);
    ref.onDispose(poll.cancel);
  }
  return page;
});

/// Whether the chat's line edits write straight in; null until answered.
final autoLineEditProvider = FutureProvider.autoDispose<bool?>((ref) => readAutoLineEdit());
