import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/providers.dart';
import '../../../mara/providers.dart';
import '../../../server/errors.dart';
import '../../../ui/state_screen.dart';
import '../../mara/cards/board_card_list.dart';

/// One of the author's boards, as Mara's Cards page lists it — editable,
/// except while a chat turn runs: the turn may be writing the same board.
class BoardReview extends ConsumerWidget {
  const BoardReview({super.key, required this.projectId, required this.boardId});
  final String projectId;
  final String boardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maps = ref.watch(storyMapsProvider(projectId));
    final templates = ref.watch(storyTemplatesProvider).value;
    final turnRunning = ref.watch(chatTurnProvider(projectId).select((s) => s.sending));
    return maps.when(
      skipLoadingOnReload: true,
      loading: () => const StateScreen(spinner: true, message: 'Opening the board…'),
      error: (e, _) => StateScreen(
        message: 'The board would not open',
        detail: messageFor(e),
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(storyMapsProvider(projectId)),
      ),
      data: (maps) {
        final board = maps.where((m) => m.authored && m.id == boardId).firstOrNull;
        if (board == null) return const StateScreen(message: 'This board is gone');
        if (board.cards.isEmpty) return const StateScreen(message: 'This board has no cards yet');
        final hints = templates?.where((t) => t.id == board.templateId).firstOrNull?.hints ?? const <String, String>{};
        return BoardCardList(projectId: projectId, board: board, hints: hints, editable: !turnRunning);
      },
    );
  }
}
