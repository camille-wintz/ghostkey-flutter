import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';
import '../../../rewards/ledger.dart';
import '../../../ui/press.dart';

/// This week · This month · This year, as one segmented control — the media
/// picker's size switch at the home's smaller scale.
class WordRangeSwitch extends StatelessWidget {
  const WordRangeSwitch({super.key, required this.value, required this.onChanged});
  final WordRange value;
  final ValueChanged<WordRange> onChanged;

  static String labelFor(WordRange range) => switch (range) {
        WordRange.week => 'This week',
        WordRange.month => 'This month',
        WordRange.year => 'This year',
      };

  @override
  Widget build(BuildContext context) => Container(
        height: 34,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Ds.surf,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          children: [
            for (final range in WordRange.values)
              Expanded(
                child: Press(
                  onPressed: () => onChanged(range),
                  semanticLabel: labelFor(range),
                  builder: (context, pressed) => AnimatedContainer(
                    duration: DsMotion.duration,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: range == value ? Ds.accentMix(12) : (pressed ? Ds.veil : const Color(0x00000000)),
                      borderRadius: BorderRadius.circular(DsGeom.radius - 2),
                    ),
                    child: Text(
                      labelFor(range),
                      style: DsStyle.ui(
                        DsText.eyebrow,
                        color: range == value ? Ds.accent200 : Ds.mid,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
