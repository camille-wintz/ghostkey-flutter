import 'package:flutter/material.dart';

import 'left_off.dart';
import 'words_section.dart';

/// What the writing room opens on, above its chapters (2026-10-02, when
/// Poltergeist was folded in and its room removed): where you left off, then
/// the words, the manuscript's standing and the latest cat — Poltergeist's
/// dashboard less its tasks. Since 2026-10-08 (Cleo) the manuscript band is
/// hidden and the latest cat sits beside where you left off.
class ApparitionHome extends StatelessWidget {
  const ApparitionHome({super.key, required this.onOpen});
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LeftOff(onOpen: onOpen),
            const SizedBox(height: 32),
            const WordsSection(),
          ],
        ),
      );
}
