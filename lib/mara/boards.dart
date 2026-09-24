import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/dto/plan.dart';
import '../server/errors.dart';
import '../server/plan/api.dart';
import 'providers.dart';

class BoardsState {
  const BoardsState({this.busy = false, this.error});
  final bool busy;
  final String? error;
}

/// The writes that act on a board as a whole: start one, name it, throw it
/// away. Each re-reads the list after; the open board is the caller's to
/// move (`openBoardProvider`).
class Boards extends Notifier<BoardsState> {
  Boards(this.projectId);
  final String projectId;

  @override
  BoardsState build() => const BoardsState();

  /// A board on [template], or blank when null — named [name] on the way in.
  /// A structure already started answers with the board that is there.
  Future<StoryMap?> start({StoryTemplate? template, String? name}) =>
      _write(() => createStoryMap(projectId, templateId: template?.id, name: name));

  /// Name a board; null takes its structure's name back.
  Future<void> rename(String mapId, String? name) => _write(() => renameStoryMap(projectId, mapId, name));

  Future<void> delete(String mapId) => _write(() async {
        await deleteStoryMap(projectId, mapId);
        ref.invalidate(authoredOutlineProvider(projectId));
      });

  void dismissError() {
    if (!state.busy) state = const BoardsState();
  }

  Future<T?> _write<T>(Future<T> Function() write) async {
    if (state.busy) return null;
    state = const BoardsState(busy: true);
    try {
      final result = await write();
      ref.invalidate(storyMapsProvider(projectId));
      await ref.read(storyMapsProvider(projectId).future);
      if (ref.mounted) state = const BoardsState();
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('[mara] board write failed: $e');
      if (ref.mounted) state = BoardsState(error: messageFor(e));
      return null;
    }
  }
}

final boardsProvider = NotifierProvider.autoDispose.family<Boards, BoardsState, String>(Boards.new);
