import 'package:flutter/material.dart';

import '../../ds/tokens.dart';

/// The panel a report's parts sit on.
class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Ds.panel,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: child,
      );
}
