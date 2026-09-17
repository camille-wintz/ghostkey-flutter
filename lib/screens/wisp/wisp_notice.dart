import 'package:flutter/material.dart';

import '../../ds/tokens.dart';

/// A line above a page's content: a run that failed, or why there is nothing
/// to read.
class WispNotice extends StatelessWidget {
  const WispNotice(this.text, {super.key, this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: error ? Color.lerp(Ds.panel, Ds.destructive, 0.08) : Ds.panel,
          border: Border.all(color: error ? Ds.destructive.withValues(alpha: 0.35) : Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Text(text, style: DsStyle.ui(DsText.ui, color: error ? Ds.destructive : Ds.mid)),
      );
}
