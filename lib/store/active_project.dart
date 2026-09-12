import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/profile.dart';
import '../server/dto/projects.dart';

/// The open project (or none) and the chapter being written in it.
///
/// The shelf and an open book are alternative ROOT screens, not a stack:
/// `open(id)` / `close()` here IS the navigation, nothing calls a navigator
/// to get between them.
class ActiveProject {
  const ActiveProject({this.projectId, this.preview, this.activeChapter, this.mark, this.ask});
  final String? projectId;

  /// The summary the book was opened from — the shelf's copy, already
  /// holding the cover thumbnail it drew — so the book can open ON its cover
  /// while the full project loads instead of on a spinner.
  final ProjectMeta? preview;

  /// The active chapter's FILENAME, as the RN app kept it.
  final String? activeChapter;

  /// What the first-run flow said this author came to do, carried exactly once
  /// so the project home can point at the room that answers it. Cleared on the
  /// first dismissal — a mark is a fact about how this book was opened, not a
  /// property of the book.
  final Intent? mark;

  /// A question to send on arrival, put here by the first-run flow's guided
  /// branch. The project home opens the chat on it instead of the room list,
  /// and clears it the moment the chat has it.
  final String? ask;

  bool get isOpen => projectId != null;
}

class ActiveProjectNotifier extends Notifier<ActiveProject> {
  @override
  ActiveProject build() => const ActiveProject();

  void open(ProjectMeta project, {Intent? mark, String? ask}) =>
      state = ActiveProject(projectId: project.id, preview: project, mark: mark, ask: ask);

  void close() => state = const ActiveProject();

  void setActiveChapter(String? filename) => state = ActiveProject(
        projectId: state.projectId,
        preview: state.preview,
        activeChapter: filename,
        mark: state.mark,
        ask: state.ask,
      );

  /// The room grid has pointed at what it was going to point at.
  void clearMark() => state = ActiveProject(
        projectId: state.projectId,
        preview: state.preview,
        activeChapter: state.activeChapter,
        ask: state.ask,
      );

  /// The chat has the question; it must not be sent twice.
  void clearAsk() => state = ActiveProject(
        projectId: state.projectId,
        preview: state.preview,
        activeChapter: state.activeChapter,
        mark: state.mark,
      );
}

final activeProjectProvider =
    NotifierProvider<ActiveProjectNotifier, ActiveProject>(ActiveProjectNotifier.new);
