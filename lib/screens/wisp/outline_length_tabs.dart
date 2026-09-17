import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';
import '../../ui/press.dart';

/// Synopsis / Extended / Detailed, shortest first — Veil's segmented tabs,
/// with each length's size under its name.
class OutlineLengthTabs extends StatelessWidget {
  const OutlineLengthTabs({super.key, required this.value, required this.onChange});
  final OutlineLength value;
  final ValueChanged<OutlineLength> onChange;

  static const _tabs = [
    (OutlineLength.synopsis, 'Synopsis', '800–1k words'),
    (OutlineLength.extended, 'Extended', '2k–5k words'),
    (OutlineLength.detailed, 'Detailed', 'By chapter'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Ds.panel,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          children: [
            for (final (length, label, words) in _tabs)
              Expanded(
                child: Press(
                  onPressed: () => onChange(length),
                  semanticLabel: '$label, $words',
                  builder: (context, pressed) {
                    final active = length == value;
                    return AnimatedContainer(
                      duration: DsMotion.duration,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? Ds.accentMix(12) : (pressed ? Ds.veil : const Color(0x00000000)),
                        borderRadius: BorderRadius.circular(DsGeom.radius - 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label.toUpperCase(),
                            style: DsStyle.eyebrow(color: active ? Ds.accent200 : Ds.low, weight: FontWeight.w600),
                          ),
                          const SizedBox(height: 1),
                          Text(words, style: DsStyle.ui(const DsStep(10, 12), color: active ? Ds.mid : Ds.faint)),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
}
