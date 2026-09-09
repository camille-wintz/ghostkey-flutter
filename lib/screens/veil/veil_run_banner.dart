import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';
import '../../veil/world_bible_run.dart';

/// What the extraction is doing, drawn from the job's own progress label —
/// or how it ended badly. Sits between the header and the roster so the
/// cards already there stay readable underneath.
class VeilRunBanner extends StatelessWidget {
  const VeilRunBanner({super.key, required this.state, required this.onDismiss});
  final WorldBibleRunState state;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final error = state.error;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Ds.accentMix(8),
        border: Border.all(color: Ds.accentMix(25)),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      child: error == null
          ? Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.progress ?? 'Starting the run…',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DsStyle.ui(DsText.ui, color: Ds.soft),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'One quick read per chapter. Your renames, notes and hidden entities are kept.',
                        style: DsStyle.ui(DsText.eyebrow, color: Ds.low),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(LucideIcons.circleAlert, size: 15, color: Ds.destructive),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(error, style: DsStyle.ui(DsText.ui, color: Ds.soft))),
                const SizedBox(width: 8),
                Press(
                  onPressed: onDismiss,
                  semanticLabel: 'Dismiss',
                  builder: (context, pressed) => Opacity(
                    opacity: pressed ? 0.7 : 1,
                    child: Text('Dismiss', style: DsStyle.ui(DsText.ui, color: Ds.mid)),
                  ),
                ),
              ],
            ),
    );
  }
}
