import 'package:flutter/material.dart';

import '../../ds/tokens.dart';

/// The brief cache probe as a page opens — not a run.
class WispPageLoading extends StatelessWidget {
  const WispPageLoading(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent)),
            const SizedBox(width: 12),
            Text(label, style: DsStyle.ui(DsText.ui, color: Ds.low)),
          ],
        ),
      );
}
