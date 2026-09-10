import 'package:flutter/material.dart';

import '../../../core/plan_markers.dart';
import '../../../ds/tokens.dart';
import '../../../ui/press.dart';

/// One chapter (or note) in the panel: its title, the plan's dot, and the
/// 2px rule when it is the one open. Every row is `DsGeom.row` tall — the
/// drag is slot arithmetic on it, as is the reveal.
class ChapterTile extends StatelessWidget {
  const ChapterTile({
    super.key,
    required this.label,
    required this.active,
    required this.nested,
    required this.onTap,
    this.marker,
    this.onLongPress,
  });

  final String label;
  final bool active;
  final bool nested;
  final PlanMarker? marker;
  final VoidCallback onTap;

  /// The row's menu, when a hold is not a lift (search, a write in flight).
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    // The active row's 2px rule is drawn inside its own box, so its label has
    // to give back the 2px or every active row shifts right as it is selected.
    final indent = (nested ? 34.0 : 20.0) - (active ? 2 : 0);
    final dot = marker;
    return Semantics(
      selected: active,
      hint: 'Hold and drag to move',
      child: Press(
        onPressed: onTap,
        onLongPress: onLongPress,
        semanticLabel: dot != null ? '$label, ${dot.label}' : label,
        builder: (context, pressed) => Container(
          height: DsGeom.row,
          padding: EdgeInsets.only(left: indent, right: 20),
          decoration: BoxDecoration(
            border: active ? Border(left: BorderSide(color: Ds.accent, width: 2)) : null,
            color: active
                ? Ds.accentMix(10)
                : pressed
                    ? Ds.veil
                    : const Color(0x00000000),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsStyle.ui(DsText.body, color: active ? Ds.hi : Ds.soft),
                ),
              ),
              if (dot != null) ...[
                const SizedBox(width: 10),
                Container(width: 6, height: 6, decoration: BoxDecoration(color: dot.color, shape: BoxShape.circle)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
