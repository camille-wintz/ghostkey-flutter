import 'package:flutter/material.dart';

import '../../ds/tokens.dart';

/// The chapters a finding or theme lives in, as quiet chips.
class ChapterChips extends StatelessWidget {
  const ChapterChips({super.key, required this.labels});
  final List<String> labels;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final label in labels)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: Ds.edge),
                  borderRadius: BorderRadius.circular(DsGeom.radius),
                ),
                child: Text(label, style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
              ),
          ],
        ),
      );
}
