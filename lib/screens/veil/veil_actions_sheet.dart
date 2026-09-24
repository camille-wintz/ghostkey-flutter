import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/sheet.dart';
import '../../veil/world_bible_run.dart';
import 'veil_action_row.dart';

/// The actions that work on the bible as a whole, in the desktop's shape:
/// Generate before any extraction; Update (the cheap incremental run, a
/// cache hit when nothing changed) and Rebuild (`force`) after. A run
/// already going is said rather than offered twice. Adding an entry by hand
/// comes first and is never gated: it costs nothing and needs no manuscript.
Future<void> showVeilActions(
  BuildContext context, {
  required VoidCallback onAdd,
  required bool hasExtraction,
  required bool hasChapters,
  required bool locked,
  required WorldBibleRunState run,
  required void Function(bool force) onRun,
}) {
  return showGkSheet<void>(
    context,
    header: SheetHeader(eyebrow: 'World bible', onClose: () => Navigator.of(context).pop()),
    builder: (sheet) {
      void pick(bool force) {
        Navigator.of(sheet).pop();
        onRun(force);
      }

      final hint = hasChapters ? null : 'Add chapters first — the bible is read from what you have written.';

      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
        children: [
          VeilActionRow(
            icon: LucideIcons.plus,
            title: 'Add an entry',
            subtitle: 'A character, place or term, written in by hand.',
            enabled: true,
            locked: false,
            onTap: () {
              Navigator.of(sheet).pop();
              onAdd();
            },
          ),
          if (run.running)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Text(
                'A run is going — ${run.progress ?? 'starting'}. Its cards land here when it finishes.',
                style: DsStyle.ui(DsText.body, color: Ds.mid),
              ),
            )
          else if (!hasExtraction)
            VeilActionRow(
              icon: LucideIcons.play,
              title: 'Generate from the story outline',
              subtitle: hint ??
                  'Reads your story outline for the characters, places and terms the manuscript has committed to.',
              enabled: hasChapters,
              locked: locked,
              onTap: () => pick(false),
            )
          else ...[
            VeilActionRow(
              icon: LucideIcons.refreshCw,
              title: 'Update',
              subtitle: hint ?? 'Re-check edited chapters. Unchanged ones are free.',
              enabled: hasChapters,
              locked: locked,
              onTap: () => pick(false),
            ),
            VeilActionRow(
              icon: LucideIcons.rotateCcw,
              title: 'Rebuild from scratch',
              subtitle: hint ??
                  'Discard the cache and re-extract from the current outline. Renames, notes and hidden entities are kept.',
              enabled: hasChapters,
              locked: locked,
              onTap: () => pick(true),
            ),
          ],
        ],
      );
    },
  );
}
