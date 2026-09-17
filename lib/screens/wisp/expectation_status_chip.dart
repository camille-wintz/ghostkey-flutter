import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';

/// Hue is state: kept is done, turned is worth a look, and left alone carries
/// no hue at all — none of the three is a fault.
class ExpectationStatusChip extends StatelessWidget {
  const ExpectationStatusChip({super.key, required this.status});
  final ExpectationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ExpectationStatus.met => ('Met', Ds.done),
      ExpectationStatus.subverted => ('Subverted', Ds.attention),
      ExpectationStatus.notAddressed => ('Not addressed', Ds.low),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      child: Text(label, style: DsStyle.ui(DsText.eyebrow, color: color)),
    );
  }
}
