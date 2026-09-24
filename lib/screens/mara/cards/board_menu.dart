import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ui/menu_sheet.dart';

enum BoardAction { rename, fill, delete }

/// What acts on the board as a whole. The fill is offered on a board on a
/// structure only — a blank board has nothing to read the book onto — and
/// waits while the book has no chapters or a fill is going.
Future<BoardAction?> showBoardMenu(
  BuildContext context, {
  required String title,
  required bool fillOffered,
  required bool fillEnabled,
}) =>
    showMenuSheet<BoardAction>(
      context,
      title: title,
      entries: [
        const MenuEntry(icon: LucideIcons.pencil, label: 'Rename board', value: BoardAction.rename),
        if (fillOffered)
          MenuEntry(icon: LucideIcons.bookOpen, label: 'Fill from your book', value: BoardAction.fill, enabled: fillEnabled),
        const MenuEntry(icon: LucideIcons.trash2, label: 'Delete board', value: BoardAction.delete, destructive: true),
      ],
    );
