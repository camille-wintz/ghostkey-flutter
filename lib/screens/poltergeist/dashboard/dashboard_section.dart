import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';

/// One blotter panel: an eyebrow, its link on the same baseline, content
/// beneath. The dashboard is a desk blotter, not a card grid — no boxes, and
/// no rule under the titles either: a page that is nothing but sections
/// reads as a stack of filing drawers once every heading is underlined.
///
/// The eyebrow is a step quieter than the house's (faint, not low) for the
/// same reason — on this page the readings come first and the filing second.
class DashboardSection extends StatelessWidget {
  const DashboardSection({super.key, required this.eyebrow, this.action, required this.child});
  final String eyebrow;

  /// A small trailing affordance beside the eyebrow — usually a page link.
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // The same vertical padding a SectionLink carries for its tap
              // target, so the eyebrow and its link sit on one line instead
              // of the label hanging 8px below the affordance beside it.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(eyebrow.toUpperCase(), style: DsStyle.eyebrow(color: Ds.faint)),
                ),
              ),
              ?action,
            ],
          ),
          Padding(padding: const EdgeInsets.only(top: 4), child: child),
        ],
      );
}

/// The blotter's quiet line — "Loading…", "No chapters yet."
class SectionNote extends StatelessWidget {
  const SectionNote(this.text, {super.key, this.italic = false});
  final String text;
  final bool italic;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: italic
              ? DsStyle.prose(DsText.body, color: Ds.low).copyWith(fontStyle: FontStyle.italic)
              : DsStyle.ui(DsText.ui, color: Ds.faint),
        ),
      );
}
