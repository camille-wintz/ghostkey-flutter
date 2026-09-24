import 'package:flutter/material.dart';

import '../ds/tokens.dart';
import 'press.dart';
import 'sheet.dart';

/// One entry of a [showMenuSheet]: what it is called, its mark, and the value
/// the sheet resolves with when it is picked.
class MenuEntry<T> {
  const MenuEntry({
    required this.icon,
    required this.label,
    required this.value,
    this.destructive = false,
    this.enabled = true,
  });
  final IconData icon;
  final String label;
  final T value;

  /// The hue says what will happen: this one takes something away.
  final bool destructive;
  final bool enabled;
}

/// What can be done to one thing, as a sheet under its name. Resolves with the
/// picked entry's value, or null when the sheet is closed.
Future<T?> showMenuSheet<T>(BuildContext context, {required String title, required List<MenuEntry<T>> entries}) =>
    showGkSheet<T>(
      context,
      header: SheetHeader(eyebrow: title, onClose: () => Navigator.of(context).pop()),
      builder: (sheet) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in entries)
              MenuRow(
                icon: entry.icon,
                label: entry.label,
                destructive: entry.destructive,
                onPressed: entry.enabled ? () => Navigator.of(sheet).pop(entry.value) : null,
              ),
          ],
        ),
      ),
    );

/// One row of a menu sheet.
class MenuRow extends StatelessWidget {
  const MenuRow({super.key, required this.icon, required this.label, required this.onPressed, this.destructive = false});
  final IconData icon;
  final String label;

  /// Null draws the row dimmed and refusing presses.
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ink = destructive ? Ds.destructive : Ds.soft;
    return Press(
      onPressed: onPressed,
      semanticLabel: label,
      builder: (context, pressed) => Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: Container(
          height: DsGeom.row,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          color: pressed ? Ds.veil : const Color(0x00000000),
          child: Row(
            children: [
              Icon(icon, size: 16, color: ink),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsStyle.ui(DsText.body, color: ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
