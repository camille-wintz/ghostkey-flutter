import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ui/sheet.dart';
import 'veil_action_row.dart';

/// What can be done to one card as a whole: rename it, or hide it. Hiding is
/// the phone's way to take a card out — reversible from the hidden pile at
/// the foot of the roster; deleting stays a desk move.
Future<void> showEntityActions(
  BuildContext context, {
  required String name,
  required VoidCallback onRename,
  required VoidCallback onHide,
}) =>
    showGkSheet<void>(
      context,
      header: SheetHeader(eyebrow: name, onClose: () => Navigator.of(context).pop()),
      builder: (sheet) {
        void pick(VoidCallback action) {
          Navigator.of(sheet).pop();
          action();
        }

        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
          children: [
            VeilActionRow(
              icon: LucideIcons.pencil,
              title: 'Rename',
              subtitle: 'The new name sticks through every re-read of the manuscript.',
              enabled: true,
              locked: false,
              onTap: () => pick(onRename),
            ),
            VeilActionRow(
              icon: LucideIcons.eyeOff,
              title: 'Hide',
              subtitle: 'Not part of the world. It stays in the hidden pile, and can come back.',
              enabled: true,
              locked: false,
              onTap: () => pick(onHide),
            ),
          ],
        );
      },
    );
