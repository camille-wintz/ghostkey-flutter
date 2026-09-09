import 'package:flutter/widgets.dart';

import '../../ds/tokens.dart';

/// The live input level as a row of bars — the last few in the accent, the
/// older ones fading with their height. Mirrors the RN RecordOverlay.
class Waveform extends StatelessWidget {
  const Waveform({super.key, required this.levels, this.liveBars = 7});
  final List<double> levels;
  final int liveBars;

  static const double height = 46;

  @override
  Widget build(BuildContext context) {
    final liveFrom = levels.length - liveBars;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < levels.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: Opacity(
                opacity: i >= liveFrom ? 1 : 0.5 + levels[i] * 0.5,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  height: (levels[i] * 44).clamp(4, 44),
                  decoration: BoxDecoration(
                    color: i >= liveFrom ? Ds.accent : Ds.accentMix(55),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
