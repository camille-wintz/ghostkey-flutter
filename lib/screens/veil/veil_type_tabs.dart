import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/press.dart';

/// All / People / Places / Terms. Shorter than the group headings because
/// they sit four across; the headings below carry the full words. A type
/// the bible has none of is dimmed, not disabled — an empty list under it
/// is still an answer.
class VeilTypeTabs extends StatelessWidget {
  const VeilTypeTabs({super.key, required this.value, required this.present, required this.onChange});

  /// Null is the "All" tab.
  final BibleEntityType? value;
  final Set<BibleEntityType> present;
  final ValueChanged<BibleEntityType?> onChange;

  @override
  Widget build(BuildContext context) {
    final tabs = <(BibleEntityType?, String)>[
      (null, 'All'),
      (BibleEntityType.character, 'People'),
      (BibleEntityType.place, 'Places'),
      (BibleEntityType.term, 'Terms'),
    ];
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Ds.panel,
        border: Border.all(color: Ds.edge),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      child: Row(
        children: [
          for (final (type, label) in tabs)
            Expanded(
              child: _Tab(
                label: label,
                active: type == value,
                empty: type != null && !present.contains(type),
                onTap: () => onChange(type),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.empty, required this.onTap});
  final String label;
  final bool active;
  final bool empty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onTap,
        semanticLabel: label,
        builder: (context, pressed) => AnimatedContainer(
          duration: DsMotion.duration,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Ds.accentMix(12) : (pressed ? Ds.veil : const Color(0x00000000)),
            borderRadius: BorderRadius.circular(DsGeom.radius - 2),
          ),
          child: Text(
            label.toUpperCase(),
            style: DsStyle.eyebrow(
              color: active ? Ds.accent200 : (empty ? Ds.faint : Ds.low),
              weight: FontWeight.w600,
            ),
          ),
        ),
      );
}
