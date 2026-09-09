import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The open project (or none) and the chapter being written in it.
///
/// The shelf and an open book are alternative ROOT screens, not a stack:
/// `open(id)` / `close()` here IS the navigation, nothing calls a navigator
/// to get between them.
class ActiveProject {
  const ActiveProject({this.projectId, this.activeChapter});
  final String? projectId;

  /// The active chapter's FILENAME, as the RN app kept it.
  final String? activeChapter;

  bool get isOpen => projectId != null;
}

class ActiveProjectNotifier extends Notifier<ActiveProject> {
  @override
  ActiveProject build() => const ActiveProject();

  void open(String projectId) => state = ActiveProject(projectId: projectId);

  void close() => state = const ActiveProject();

  void setActiveChapter(String? filename) =>
      state = ActiveProject(projectId: state.projectId, activeChapter: filename);
}

final activeProjectProvider =
    NotifierProvider<ActiveProjectNotifier, ActiveProject>(ActiveProjectNotifier.new);
