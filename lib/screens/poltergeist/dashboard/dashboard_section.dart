import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';

/// One blotter panel: an eyebrow on a ruled line, content beneath. The
/// dashboard is a desk blotter, not a card grid — panels share the ledger's
/// hairline rules rather than boxes.
class DashboardSection extends StatelessWidget {
  const DashboardSection({super.key, required this.eyebrow, this.action, required this.child});
  final String eyebrow;

  /// A small trailing affordance on the rule — usually a page link.
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 30),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(eyebrow.toUpperCase(), style: DsStyle.eyebrow(weight: FontWeight.w600)),
                  ),
                ),
                ?action,
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.only(top: 14), child: child),
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
