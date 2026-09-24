import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/plan.dart';
import '../server/plan/api.dart';

// Mara's server reads — also what the chat's Review reads when a turn opened
// a board, the outline or the chapters. A write calls the api and
// invalidates what it moved; nothing patches these locally.

/// Every story map of the project, both sources.
final storyMapsProvider = FutureProvider.autoDispose.family<List<StoryMap>, String>(
  (ref, projectId) => listStoryMaps(projectId),
);

/// The Outline row: the prose, and the proposal or changeset on it.
final authoredOutlineProvider = FutureProvider.autoDispose.family<AuthoredOutline, String>(
  (ref, projectId) => getAuthoredOutline(projectId),
);

/// The structures a board can be started on. The same for every author, so
/// kept for the session.
final storyTemplatesProvider = FutureProvider<List<StoryTemplate>>((ref) => listStoryTemplates());

/// One of the author's boards and what it is called, as the picker lists it.
typedef BoardEntry = ({StoryMap board, String title, String? structure});

/// The author's boards, by name — a list a board is picked out of has to hold
/// still, and the server's order moves with every edit.
final boardListProvider = Provider.autoDispose.family<AsyncValue<List<BoardEntry>>, String>((ref, projectId) {
  final templates = ref.watch(storyTemplatesProvider).value ?? const <StoryTemplate>[];
  return ref.watch(storyMapsProvider(projectId)).whenData(
        (maps) => [
          for (final board in maps.where((m) => m.authored))
            _entry(board, templates.where((t) => t.id == board.templateId).firstOrNull),
        ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())),
      );
});

BoardEntry _entry(StoryMap board, StoryTemplate? template) =>
    (board: board, title: boardTitle(board, template?.name), structure: template?.name);

/// What a blank board nobody has named yet is called on the way in, and the
/// numbered names after it.
const String blankBoardName = 'Blank board';

/// The first of "Blank board", "Blank board 2", … no board is using.
String nextBlankBoardName(Iterable<String?> taken) {
  final names = taken.toSet();
  var name = blankBoardName;
  for (var n = 2; names.contains(name); n++) {
    name = '$blankBoardName $n';
  }
  return name;
}
