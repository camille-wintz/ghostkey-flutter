import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/errors.dart';
import '../server/plan/api.dart';
import 'providers.dart';

/// One board of one book.
typedef BoardKey = ({String projectId, String mapId});

class BoardEditState {
  const BoardEditState({this.writing = false, this.error});

  /// A write is on its way and the board has not been re-read after it — the
  /// list takes no second drag until it has.
  final bool writing;

  /// Why the last write did not land.
  final String? error;
}

/// The board's structural writes — add, move, relink, duplicate, delete —
/// one at a time. Each is the server's route, then a re-read of the board:
/// the server owns what a move does to the chains, so the client never
/// guesses at the result. Also re-reads the Outline row, since a change to a
/// board voids a proposal made from it.
class BoardEdits extends Notifier<BoardEditState> {
  BoardEdits(this.board);
  final BoardKey board;

  @override
  BoardEditState build() => const BoardEditState();

  /// A new card (or label) at the end of the board; its id, or null when the
  /// write failed.
  Future<String?> add({bool label = false}) =>
      _write(() async => (await addStoryCard(board.projectId, board.mapId, label: label)).cardId);

  /// Straight after [afterId], or first when null.
  Future<void> move(String cardId, String? afterId) =>
      _write(() => patchStoryCard(board.projectId, board.mapId, cardId, move: true, afterId: afterId));

  Future<void> startChain(String cardId) =>
      _write(() => patchStoryCard(board.projectId, board.mapId, cardId, startsChain: true));

  Future<void> joinAbove(String cardId) =>
      _write(() => patchStoryCard(board.projectId, board.mapId, cardId, startsChain: false));

  Future<String?> duplicate(String cardId) =>
      _write(() async => (await duplicateStoryCard(board.projectId, board.mapId, cardId)).cardId);

  Future<void> delete(String cardId) => _write(() => deleteStoryCard(board.projectId, board.mapId, cardId));

  void dismissError() {
    if (!state.writing) state = const BoardEditState();
  }

  Future<T?> _write<T>(Future<T> Function() write) async {
    if (state.writing) return null;
    state = const BoardEditState(writing: true);
    try {
      final result = await write();
      await _reread();
      if (ref.mounted) state = const BoardEditState();
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('[mara] board write failed: $e');
      if (ref.mounted) state = BoardEditState(error: messageFor(e));
      await _reread();
      return null;
    }
  }

  Future<void> _reread() async {
    if (!ref.mounted) return;
    ref.invalidate(authoredOutlineProvider(board.projectId));
    ref.invalidate(storyMapsProvider(board.projectId));
    try {
      await ref.read(storyMapsProvider(board.projectId).future);
    } catch (_) {
      // The page shows a failed read itself.
    }
  }
}

final boardEditsProvider =
    NotifierProvider.autoDispose.family<BoardEdits, BoardEditState, BoardKey>(BoardEdits.new);

/// One card's words, written as typed: its title or its description. Takes
/// the container rather than a ref because the last keystroke is flushed as
/// the card page goes away, after its own ref has.
Future<void> saveCardText(
  ProviderContainer container,
  BoardKey board,
  String cardId, {
  String? title,
  String? description,
}) async {
  await patchStoryCard(board.projectId, board.mapId, cardId, title: title, description: description);
  container.invalidate(storyMapsProvider(board.projectId));
  container.invalidate(authoredOutlineProvider(board.projectId));
}
