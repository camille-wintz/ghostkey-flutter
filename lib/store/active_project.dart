import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/profile.dart';

/// The open project (or none) and the chapter being written in it.
///
/// The shelf and an open book are alternative ROOT screens, not a stack:
/// `open(id)` / `close()` here IS the navigation, nothing calls a navigator
/// to get between them.
class ActiveProject {
  const ActiveProject({this.projectId, this.activeChapter, this.mark, this.ask});
  final String? projectId;

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

  void open(String projectId, {Intent? mark, String? ask}) =>
      state = ActiveProject(projectId: projectId, mark: mark, ask: ask);

  void close() => state = const ActiveProject();

  void setActiveChapter(String? filename) => state = ActiveProject(
        projectId: state.projectId,
        activeChapter: filename,
        mark: state.mark,
        ask: state.ask,
      );

  /// The room grid has pointed at what it was going to point at.
  void clearMark() => state = ActiveProject(
        projectId: state.projectId,
        activeChapter: state.activeChapter,
        ask: state.ask,
      );

  /// The chat has the question; it must not be sent twice.
  void clearAsk() => state = ActiveProject(
        projectId: state.projectId,
        activeChapter: state.activeChapter,
        mark: state.mark,
      );
}

final activeProjectProvider =
    NotifierProvider<ActiveProjectNotifier, ActiveProject>(ActiveProjectNotifier.new);
