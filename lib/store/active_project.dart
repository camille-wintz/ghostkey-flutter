import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/projects.dart';

/// A library file the book's chat should open on: a failed import's, handed
/// to the chat to bring in by hand.
typedef ChatLanding = ({String itemId, String title});

/// The open project (or none) and the chapter being written in it.
///
/// The shelf and an open book are alternative ROOT screens, not a stack:
/// `open(id)` / `close()` here IS the navigation, nothing calls a navigator
/// to get between them.
class ActiveProject {
  const ActiveProject({this.projectId, this.preview, this.activeChapter, this.chatLanding});
  final String? projectId;

  /// The summary the book was opened from — the shelf's copy, already
  /// holding the cover thumbnail it drew — so the book can open ON its cover
  /// while the full project loads instead of on a spinner.
  final ProjectMeta? preview;

  /// The active chapter's FILENAME, as the RN app kept it.
  final String? activeChapter;

  /// Where the book lands once it has loaded, instead of its home: its chat,
  /// with this file attached. The shelf cannot push into a book's navigator,
  /// so it leaves this for `ProjectRoot`, which takes it once.
  final ChatLanding? chatLanding;

  bool get isOpen => projectId != null;
}

class ActiveProjectNotifier extends Notifier<ActiveProject> {
  @override
  ActiveProject build() => const ActiveProject();

  void open(ProjectMeta project, {ChatLanding? chatLanding}) =>
      state = ActiveProject(projectId: project.id, preview: project, chatLanding: chatLanding);

  void close() => state = const ActiveProject();

  void setActiveChapter(String? filename) => state = ActiveProject(
        projectId: state.projectId,
        preview: state.preview,
        activeChapter: filename,
        chatLanding: state.chatLanding,
      );

  /// The pending landing, once: it is cleared as it is read.
  ChatLanding? takeChatLanding() {
    final landing = state.chatLanding;
    if (landing == null) return null;
    state = ActiveProject(projectId: state.projectId, preview: state.preview, activeChapter: state.activeChapter);
    return landing;
  }
}

final activeProjectProvider =
    NotifierProvider<ActiveProjectNotifier, ActiveProject>(ActiveProjectNotifier.new);
