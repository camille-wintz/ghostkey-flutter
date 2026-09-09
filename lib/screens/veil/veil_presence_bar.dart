import 'package:flutter/material.dart';

import '../../ds/tokens.dart';

/// How much of a book an entity is in, against the book's busiest entity. A
/// bare count answers "how many"; this answers "compared with whom", which is
/// the question a cast list is actually scanned for. Caller-unaware: a
/// fraction and a tone.
class VeilPresenceBar extends StatelessWidget {
  const VeilPresenceBar({super.key, required this.fraction, required this.tone, this.width});

  /// 0–1, already floored by the caller so a walk-on still reads as present.
  final double fraction;
  final Color tone;

  /// Fixed when given; fills the parent otherwise.
  final double? width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 2,
        decoration: BoxDecoration(color: Ds.veilHi, borderRadius: BorderRadius.circular(DsGeom.radiusRound)),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0, 1),
          child: ColoredBox(color: tone),
        ),
      );
}
