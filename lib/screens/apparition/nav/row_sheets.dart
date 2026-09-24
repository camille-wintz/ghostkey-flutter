import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ui/confirm_sheet.dart';
import '../../../ui/menu_sheet.dart';
import '../../../ui/name_sheet.dart';

// The three small sheets a held row can open: its menu, the rename, and the
// delete confirmation. Sheets rather than dialogs — the list stays visible
// behind them, which is where the row came from.

enum RowAction { rename, delete }

/// What can be done to a row: rename it, or delete it.
Future<RowAction?> showRowMenu(BuildContext context, {required String label}) => showMenuSheet<RowAction>(
      context,
      title: label,
      entries: const [
        MenuEntry(icon: LucideIcons.pencil, label: 'Rename', value: RowAction.rename),
        MenuEntry(icon: LucideIcons.trash2, label: 'Delete', value: RowAction.delete, destructive: true),
      ],
    );

/// A new title for the row, or null — also when it is unchanged.
Future<String?> showRenameSheet(BuildContext context, {required String current}) async {
  final next = await showNameSheet(context, eyebrow: 'Rename', current: current, action: 'Rename');
  return next == null || next == current.trim() ? null : next;
}

/// Whether to go through with a delete. Deleting is not undoable from here,
/// so it asks once.
Future<bool> confirmDelete(BuildContext context, {required String label}) => showConfirmSheet(
      context,
      eyebrow: 'Delete',
      title: 'Delete "$label"?',
      message: 'Its text goes with it.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
      destructive: true,
    );
