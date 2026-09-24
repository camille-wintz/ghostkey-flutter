import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mara/board_edits.dart';
import '../../../mara/providers.dart';
import '../../../ui/state_screen.dart';
import '../mara_page_frame.dart';
import 'card_page_fields.dart';

/// One card, full screen: its title and what happens there, saved as typed
/// (a pause, or leaving the page). A label has its title alone.
class CardPage extends ConsumerWidget {
  const CardPage({super.key, required this.board, required this.cardId, this.hint});
  final BoardKey board;
  final String cardId;

  /// The beat's question, as the description's placeholder.
  final String? hint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maps = ref.watch(storyMapsProvider(board.projectId));
    final card = maps.value
        ?.where((m) => m.id == board.mapId)
        .firstOrNull
        ?.cards
        .where((c) => c.id == cardId)
        .firstOrNull;
    return MaraPageFrame(
      title: card?.isLabel ?? false ? 'Label' : 'Card',
      child: switch (card) {
        final card? => CardPageFields(
            // Read once, as the page opens: the fields are the author's from
            // then on, and a re-read never lands under their typing.
            key: ValueKey(card.id),
            board: board,
            card: card,
            hint: hint,
          ),
        null when maps.isLoading => const StateScreen(spinner: true, message: 'Opening the card…'),
        null => const StateScreen(message: 'This card is gone'),
      },
    );
  }
}
