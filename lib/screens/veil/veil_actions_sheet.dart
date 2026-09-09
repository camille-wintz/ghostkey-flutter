import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';
import '../../ui/sheet.dart';
import '../../veil/world_bible_run.dart';

/// The actions that work on the bible as a whole, in the desktop's shape:
/// Generate before any extraction; Update (the cheap incremental run, a
/// cache hit when nothing changed) and Rebuild (`force`) after. A run
/// already going is said rather than offered twice.
Future<void> showVeilActions(
  BuildContext context, {
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
          if (run.running)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Text(
                'A run is going — ${run.progress ?? 'starting'}. Its cards land here when it finishes.',
                style: DsStyle.ui(DsText.body, color: Ds.mid),
              ),
            )
          else if (!hasExtraction)
            _ActionRow(
              icon: LucideIcons.play,
              title: 'Generate from the story outline',
              subtitle: hint ??
                  'Reads your story outline for the characters, places and terms the manuscript has committed to.',
              enabled: hasChapters,
              locked: locked,
              onTap: () => pick(false),
            )
          else ...[
            _ActionRow(
              icon: LucideIcons.refreshCw,
              title: 'Update',
              subtitle: hint ?? 'Re-check edited chapters. Unchanged ones are free.',
              enabled: hasChapters,
              locked: locked,
              onTap: () => pick(false),
            ),
            _ActionRow(
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.locked,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;

  /// Not on the plan: drawn with a padlock and still tappable, so the tap
  /// can explain which plan opens it.
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onTap,
        enabled: enabled,
        semanticLabel: title,
        builder: (context, pressed) => Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: pressed ? Ds.veil : const Color(0x00000000),
              borderRadius: BorderRadius.circular(DsGeom.radius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 17, color: Ds.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: DsStyle.ui(DsText.body, color: Ds.hi, weight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: DsStyle.ui(DsText.ui, color: Ds.mid)),
                    ],
                  ),
                ),
                if (locked)
                  Padding(
                    padding: const EdgeInsets.only(left: 10, top: 3),
                    child: Icon(LucideIcons.lock, size: 15, color: Ds.faint),
                  ),
              ],
            ),
          ),
        ),
      );
}
