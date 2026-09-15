import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/projects.dart';

/// The open project (or none) and the chapter being written in it.
///
/// The shelf and an open book are alternative ROOT screens, not a stack:
/// `open(id)` / `close()` here IS the navigation, nothing calls a navigator
/// to get between them.
class ActiveProject {
  const ActiveProject({this.projectId, this.preview, this.activeChapter});
  final String? projectId;

  /// The summary the book was opened from — the shelf's copy, already
  /// holding the cover thumbnail it drew — so the book can open ON its cover
  /// while the full project loads instead of on a spinner.
  final ProjectMeta? preview;

  /// The active chapter's FILENAME, as the RN app kept it.
  final String? activeChapter;

  bool get isOpen => projectId != null;
}

class ActiveProjectNotifier extends Notifier<ActiveProject> {
  @override
  ActiveProject build() => const ActiveProject();

  void open(ProjectMeta project) => state = ActiveProject(projectId: project.id, preview: project);

  void close() => state = const ActiveProject();

  void setActiveChapter(String? filename) => state = ActiveProject(
        projectId: state.projectId,
        preview: state.preview,
        activeChapter: filename,
      );
}

final activeProjectProvider =
    NotifierProvider<ActiveProjectNotifier, ActiveProject>(ActiveProjectNotifier.new);
