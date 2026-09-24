import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/jobs/job_run.dart';
import '../server/providers.dart';
import 'providers.dart';

/// "Fill from your book": the `book_map` job, told to copy what it reads
/// over one board as its last step (`adopt_into`). Tagged with that board's
/// id, so a board can tell its own fill from another's.
class BoardFillRun extends JobRun {
  BoardFillRun(String projectId) : super((projectId: projectId, kind: 'book_map', subject: null));

  @override
  Duration get patience => const Duration(minutes: 90);

  /// Fill [mapId], a board on the structure [templateId].
  Future<void> fill({required String mapId, required String templateId}) =>
      start({'template': templateId, 'adopt_into': mapId}, tag: mapId);

  @override
  void onLanded() {
    ref.invalidate(storyMapsProvider(key.projectId));
    ref.invalidate(authoredOutlineProvider(key.projectId));
    ref.invalidate(quotaProvider);
  }
}

final boardFillRunProvider =
    NotifierProvider.autoDispose.family<BoardFillRun, JobRunState, String>(BoardFillRun.new);

/// "Fill from the book" on the Outline: the `outline_sketch` job writes the
/// outline from the manuscript. `replace` is the author's second yes over an
/// outline they already wrote.
class OutlineSketchRun extends JobRun {
  OutlineSketchRun(String projectId) : super((projectId: projectId, kind: 'outline_sketch', subject: null));

  Future<void> sketch({required bool replace}) => start({if (replace) 'force': true});

  @override
  void onLanded() {
    ref.invalidate(authoredOutlineProvider(key.projectId));
    ref.invalidate(quotaProvider);
  }
}

final outlineSketchRunProvider =
    NotifierProvider.autoDispose.family<OutlineSketchRun, JobRunState, String>(OutlineSketchRun.new);
