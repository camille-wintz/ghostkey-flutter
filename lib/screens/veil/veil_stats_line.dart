import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../veil/roster.dart';

/// "14 entities · 9 characters · 6 dossiers · 3 portraits" — the one part of
/// the desktop's landing page that fits a phone.
class VeilStatsLine extends StatelessWidget {
  const VeilStatsLine({super.key, required this.stats});
  final BibleStats stats;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
        child: Text(stats.line, style: DsStyle.ui(DsText.ui, color: Ds.low)),
      );
}
