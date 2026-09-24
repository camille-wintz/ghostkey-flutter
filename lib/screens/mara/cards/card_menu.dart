import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../mara/board_edits.dart';
import '../../../mara/chains.dart';
import '../../../ui/confirm_sheet.dart';
import '../../../ui/menu_sheet.dart';

enum _CardAction { duplicate, startChain, joinAbove, delete }

/// What can be done to one card: copy it, start or close a chain at it, or
/// take it off the board. The chain entries are offered only where they
/// apply — the server decides what either does to the links.
Future<void> showCardMenu(BuildContext context, WidgetRef ref, BoardKey board, ChainedCard chained) async {
  final card = chained.card;
  final title = card.title.trim().isEmpty ? (card.isLabel ? 'Label' : 'Untitled card') : card.title.trim();
  final action = await showMenuSheet<_CardAction>(
    context,
    title: title,
    entries: [
      const MenuEntry(icon: LucideIcons.copy, label: 'Duplicate', value: _CardAction.duplicate),
      if (chained.canStartChain)
        const MenuEntry(icon: LucideIcons.unlink, label: 'Start a new chain here', value: _CardAction.startChain),
      if (chained.canJoinAbove)
        const MenuEntry(icon: LucideIcons.link, label: 'Join the card above', value: _CardAction.joinAbove),
      const MenuEntry(icon: LucideIcons.trash2, label: 'Delete', value: _CardAction.delete, destructive: true),
    ],
  );
  if (action == null || !context.mounted) return;
  final edits = ref.read(boardEditsProvider(board).notifier);
  switch (action) {
    case _CardAction.duplicate:
      await edits.duplicate(card.id);
    case _CardAction.startChain:
      await edits.startChain(card.id);
    case _CardAction.joinAbove:
      await edits.joinAbove(card.id);
    case _CardAction.delete:
      final ok = await showConfirmSheet(
        context,
        eyebrow: 'Delete',
        title: card.isLabel ? 'Delete this label?' : 'Delete this card?',
        message: card.isLabel ? 'The cards under it stay on the board.' : 'What it says goes with it.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (ok) await edits.delete(card.id);
  }
}
