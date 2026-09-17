import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/review/providers.dart';
import '../../../server/dto/plan.dart';
import '../../../server/errors.dart';
import '../../../ui/state_screen.dart';
import 'story_card_tile.dart';

/// One of the author's boards, read only: its cards in order, section marks
/// as headings. The board itself is edited on the desk.
class BoardReview extends ConsumerWidget {
  const BoardReview({super.key, required this.projectId, required this.boardId});
  final String projectId;
  final String boardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maps = ref.watch(storyMapsProvider(projectId));
    return maps.when(
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
        final cards = _flatten(board.nodes);
        if (cards.isEmpty) return const StateScreen(message: 'This board has no cards yet');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
          itemCount: cards.length,
          separatorBuilder: (context, i) => SizedBox(height: cards[i + 1].isLabel ? 24 : 10),
          itemBuilder: (context, i) => StoryCardTile(card: cards[i]),
        );
      },
    );
  }

  /// Boards saved before the plan went flat nest their beats; every reader
  /// flattens them.
  static List<StoryCard> _flatten(List<StoryCard> cards) => [
        for (final card in cards) ...[card, ..._flatten(card.cards)],
      ];
}
