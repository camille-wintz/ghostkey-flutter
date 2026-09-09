import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../ui/button.dart';
import '../../../ui/field.dart';
import '../../../ui/press.dart';
import '../../../ui/sheet.dart';

// The three small sheets a held row can open: its menu, the rename, and the
// delete confirmation. Sheets rather than dialogs — the list stays visible
// behind them, which is where the row came from.

enum RowAction { rename, delete }

/// What can be done to a row: rename it, or delete it.
Future<RowAction?> showRowMenu(BuildContext context, {required String label}) => showGkSheet<RowAction>(
      context,
      header: SheetHeader(eyebrow: label, onClose: () => Navigator.of(context).pop()),
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuRow(icon: LucideIcons.pencil, label: 'Rename', onPressed: () => Navigator.of(context).pop(RowAction.rename)),
            _MenuRow(
              icon: LucideIcons.trash2,
              label: 'Delete',
              destructive: true,
              onPressed: () => Navigator.of(context).pop(RowAction.delete),
            ),
          ],
        ),
      ),
    );

/// A new title for the row, or null.
Future<String?> showRenameSheet(BuildContext context, {required String current}) => showGkSheet<String>(
      context,
      header: SheetHeader(eyebrow: 'Rename', onClose: () => Navigator.of(context).pop()),
      builder: (context) => _RenameForm(current: current),
    );

/// Whether to go through with a delete. Deleting is not undoable from here,
/// so it asks once.
Future<bool> confirmDelete(BuildContext context, {required String label}) async {
  final answer = await showGkSheet<bool>(
    context,
    header: SheetHeader(eyebrow: 'Delete', onClose: () => Navigator.of(context).pop()),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Delete "$label"?', style: DsStyle.prose(DsText.title, weight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text('Its text goes with it.', style: DsStyle.ui(DsText.body, color: Ds.mid)),
          const SizedBox(height: 20),
          _DestructiveButton(label: 'Delete', onPressed: () => Navigator.of(context).pop(true)),
          const SizedBox(height: 10),
          GkButton(label: 'Keep', variant: ButtonVariant.outline, wide: true, onPressed: () => Navigator.of(context).pop(false)),
        ],
      ),
    ),
  );
  return answer ?? false;
}

class _RenameForm extends StatefulWidget {
  const _RenameForm({required this.current});
  final String current;

  @override
  State<_RenameForm> createState() => _RenameFormState();
}

class _RenameFormState extends State<_RenameForm> {
  late final TextEditingController _title = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    final next = _title.text.trim();
    Navigator.of(context).pop(next.isEmpty || next == widget.current ? null : next);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GkField(
              controller: _title,
              autofocus: true,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            GkButton(label: 'Rename', wide: true, onPressed: _submit),
          ],
        ),
      );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onPressed, this.destructive = false});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ink = destructive ? Ds.destructive : Ds.soft;
    return Press(
      onPressed: onPressed,
      semanticLabel: label,
      builder: (context, pressed) => Container(
        height: DsGeom.row,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: pressed ? Ds.veil : const Color(0x00000000),
        child: Row(
          children: [
            Icon(icon, size: 16, color: ink),
            const SizedBox(width: 12),
            Text(label, style: DsStyle.ui(DsText.body, color: ink)),
          ],
        ),
      ),
    );
  }
}

/// The one button that is not the accent: the hue means what will happen.
class _DestructiveButton extends StatelessWidget {
  const _DestructiveButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: label,
        builder: (context, pressed) => Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DsGeom.radius),
            border: Border.all(color: Ds.destructive.withValues(alpha: pressed ? 1 : 0.55)),
            color: Ds.destructive.withValues(alpha: pressed ? 0.2 : 0.12),
          ),
          child: Text(
            label.toUpperCase(),
            style: DsStyle.ui(DsText.ui, color: Ds.destructive, weight: FontWeight.w600, tracking: DsTracking.control),
          ),
        ),
      );
}
