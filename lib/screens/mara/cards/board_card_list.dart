import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mara/board_edits.dart';
import '../../../mara/chains.dart';
import '../../../server/dto/plan.dart';
import 'card_menu.dart';
import 'card_page.dart';
import 'story_card_list.dart';

/// One of the author's boards as the card list, wired to the board's writes:
/// a card held and dropped moves, a tap opens its page, ⋯ opens its menu.
/// Read-only when [editable] is false — the chat, mid-turn.
class BoardCardList extends ConsumerWidget {
  const BoardCardList({
    super.key,
    required this.projectId,
    required this.board,
    required this.editable,
    this.hints = const {},
    this.header,
    this.footer,
  });

  final String projectId;
  final StoryMap board;
  final bool editable;
  final Map<String, String> hints;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (projectId: projectId, mapId: board.id);
    final writing = ref.watch(boardEditsProvider(key).select((s) => s.writing));
    final cards = board.cards;

    void open(StoryCard card) => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CardPage(board: key, cardId: card.id, hint: card.key == null ? null : hints[card.key]),
          ),
        );

    void menu(StoryCard card) {
      final chained = chainCards(cards, board.roots).where((c) => c.card.id == card.id).firstOrNull;
      if (chained != null) showCardMenu(context, ref, key, chained);
    }

    return StoryCardList(
      cards: cards,
      roots: board.roots,
      hints: hints,
      busy: writing,
      header: header,
      footer: footer,
      onOpen: editable ? open : null,
      onMenu: editable ? menu : null,
      onMove: editable ? (cardId, afterId) => ref.read(boardEditsProvider(key).notifier).move(cardId, afterId) : null,
    );
  }
}
