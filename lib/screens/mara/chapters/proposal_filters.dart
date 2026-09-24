import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../mara/proposal.dart';
import '../../../ui/press.dart';
import 'status_colors.dart';

/// What the proposal is made of, as the way to look at one part of it — and,
/// when chapters were dropped this visit, the way to put them back.
class ProposalFilters extends StatelessWidget {
  const ProposalFilters({
    super.key,
    required this.filters,
    required this.active,
    required this.onSelect,
    required this.dropped,
    required this.onRestore,
  });
  final List<StatusFilter> filters;
  final ChapterStatus? active;
  final ValueChanged<ChapterStatus?> onSelect;
  final int dropped;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final f in filters) ...[
                _Chip(
                  label: f.status?.label ?? 'All',
                  count: f.count,
                  dot: f.status == null ? null : statusColor(f.status!),
                  selected: f.status == active,
                  onPressed: () => onSelect(f.status),
                ),
                const SizedBox(width: 8),
              ],
              if (dropped > 0)
                Press(
                  onPressed: onRestore,
                  semanticLabel: 'Restore $dropped dropped',
                  builder: (context, pressed) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Row(
                      children: [
                        Icon(LucideIcons.undo2, size: 13, color: pressed ? Ds.accent : Ds.low),
                        const SizedBox(width: 6),
                        Text('$dropped dropped · restore'.toUpperCase(), style: DsStyle.eyebrow(color: pressed ? Ds.accent : Ds.low)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.count, required this.dot, required this.selected, required this.onPressed});
  final String label;
  final int count;
  final Color? dot;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: '$label, $count${selected ? ', showing' : ''}',
        builder: (context, pressed) => AnimatedContainer(
          duration: DsMotion.duration,
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? Ds.accentMix(10) : (pressed ? Ds.veil : const Color(0x00000000)),
            border: Border.all(color: selected ? Ds.accent600 : Ds.edge),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot case final dot?) ...[
                Container(width: 5, height: 5, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 7),
              ],
              Text(label.toUpperCase(), style: DsStyle.eyebrow(color: selected ? Ds.accent200 : Ds.mid)),
              const SizedBox(width: 6),
              Text('$count', style: DsStyle.eyebrow(color: Ds.faint)),
            ],
          ),
        ),
      );
}
