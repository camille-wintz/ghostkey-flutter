import 'package:flutter/material.dart';

import '../ds/tokens.dart';

/// What a room's list panel says about itself: the book it belongs to, and one
/// line of meta under the name.
///
/// It is not a control. The way out of a room is the chevron in the room's own
/// chrome and nowhere else — a second door at the head of a list is the same
/// exit worn twice, which is what made the rooms read as separate apps. This
/// only answers "which book am I in", which the rooms that show a chapter's
/// name rather than the book's would otherwise stop saying.
class PanelHead extends StatelessWidget {
  const PanelHead({super.key, required this.title, this.meta});

  final String title;

  /// What this panel holds, in the app's own words. Absent while it loads.
  final String? meta;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsStyle.prose(const DsStep(20, 26), weight: FontWeight.w600),
            ),
            if (meta != null) ...[
              const SizedBox(height: 4),
              Text(meta!, style: DsStyle.ui(DsText.eyebrow, color: Ds.low, tracking: DsTracking.pill)),
            ],
          ],
        ),
      );
}
