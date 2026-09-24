import 'package:flutter/material.dart';

import '../ds/tokens.dart';

/// The bar under a page's scroll: what the page does, cut off from what it
/// shows by a hairline, and clear of the system's own bar.
class PageFooter extends StatelessWidget {
  const PageFooter({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: Ds.panel, border: Border(top: BorderSide(color: Ds.edge))),
        child: SafeArea(
          top: false,
          child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: child),
        ),
      );
}
