import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';

/// One panel of Apparition's home (Poltergeist's dashboard, folded in on
/// 2026-10-02): an eyebrow, its link on the same baseline, content beneath.
/// A desk blotter, not a card grid — no boxes, and no rule under the titles
/// either: a page of sections reads as a stack of filing drawers once every
/// heading is underlined.
///
/// The eyebrow is a step quieter than the house's (faint, not low) for the
/// same reason — the readings come first and the filing second.
class HomeSection extends StatelessWidget {
  const HomeSection({super.key, required this.eyebrow, this.action, required this.child});
  final String eyebrow;

  /// A small trailing affordance beside the eyebrow — a link, or a figure.
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // The same vertical padding the action beside it carries for its
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

/// The home's quiet line — "Loading…", "No chapters yet."
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
