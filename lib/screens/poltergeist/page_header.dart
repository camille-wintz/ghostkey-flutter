import 'package:flutter/material.dart';

import '../../ds/tokens.dart';

/// Every page in the ledger opens the same way — a title and its count, on
/// the rule the content hangs from.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.meta, this.metaWidget, this.actions = const [], this.rule = true});
  final String title;

  /// The right-hand figure: what this page is counting.
  final String? meta;

  /// A richer meta than a string — the board's "checking" line.
  final Widget? metaWidget;

  /// Controls that act on the whole page.
  final List<Widget> actions;
  final bool rule;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: DsGeom.row),
        decoration: rule ? BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))) : null,
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsStyle.prose(DsText.title, weight: FontWeight.w600),
              ),
            ),
            if (metaWidget != null) metaWidget! else if (meta != null) PageMeta(meta!),
            for (final action in actions) ...[const SizedBox(width: 10), action],
          ],
        ),
      );
}

/// The uppercase, tracked figure on a page header's rule.
class PageMeta extends StatelessWidget {
  const PageMeta(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DsStyle.ui(DsText.eyebrow, color: color ?? Ds.low, tracking: 11 * 0.12)
            .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      );
}
