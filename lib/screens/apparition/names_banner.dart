import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// "Pathfinder and The Watcher's Memoirs" — the names themselves, so the
/// author can tell at a glance whether this is worth opening.
String nameList(List<String> names) {
  if (names.length <= 2) return names.join(' and ');
  return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
}

/// The names this chapter introduced that the world bible has not filed.
///
/// Amber because it wants attention, not because it is a warning — nothing
/// has gone wrong, and the author can ignore it forever. It sits above the
/// prose rather than over it: a modal on chapter open would interrupt the one
/// thing this room exists for.
class NamesBanner extends StatelessWidget {
  const NamesBanner({super.key, required this.names, required this.onReview, required this.onLater});
  final List<String> names;
  final VoidCallback onReview;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final count = names.length;
    final one = count == 1;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Ds.attentionMix(32)),
        borderRadius: BorderRadius.circular(DsGeom.radius),
        color: Ds.attentionMix(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.tag, size: 14, color: Ds.attention400),
              const SizedBox(width: 8),
              Text(
                one ? 'ONE NEW NAME' : '$count NEW NAMES',
                style: DsStyle.eyebrow(color: Ds.attention300),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "${nameList(names)} ${one ? 'appears' : 'appear'} in this chapter and ${one ? "isn't" : "aren't"} in your world bible yet.",
            style: DsStyle.ui(DsText.ui, color: Ds.soft).copyWith(height: 19 / DsText.ui.size),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Press(
                  onPressed: onReview,
                  semanticLabel: 'Review names',
                  builder: (context, pressed) => Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(DsGeom.radius),
                      border: Border.all(color: pressed ? Ds.accent : Ds.accentMix(55)),
                      color: Ds.accentMix(pressed ? 20 : 12),
                    ),
                    child: Text(
                      'REVIEW NAMES',
                      style: DsStyle.ui(DsText.ui, color: Ds.accent, weight: FontWeight.w600, tracking: DsTracking.control),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Press(
                onPressed: onLater,
                semanticLabel: 'Later',
                builder: (context, pressed) => Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(DsGeom.radius),
                    border: Border.all(color: Ds.edgeHi),
                    color: pressed ? Ds.veil : const Color(0x00000000),
                  ),
                  child: Text(
                    'LATER',
                    style: DsStyle.ui(DsText.ui, color: Ds.soft, weight: FontWeight.w600, tracking: DsTracking.control),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
