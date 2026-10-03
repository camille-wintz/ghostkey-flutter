import 'package:flutter/material.dart';

import '../../../next_scene/next_scene_finder.dart';
import '../../../server/dto/next_scene.dart';
import 'latest_cat.dart';
import 'left_off.dart';
import 'manuscript_band.dart';
import 'words_section.dart';

/// What the writing room opens on, above its chapters (2026-10-02, when
/// Poltergeist was folded in and its room removed): where you left off with
/// "Find me a scene to write" beside it, then the words, the manuscript's
/// standing and the latest cat — Poltergeist's dashboard less its tasks.
class ApparitionHome extends StatelessWidget {
  const ApparitionHome({
    super.key,
    required this.finder,
    required this.onOpen,
    required this.onWrite,
    required this.onStuck,
    required this.stuckPending,
  });
  final NextSceneFinder finder;
  final ValueChanged<String> onOpen;
  final ValueChanged<NextScene> onWrite;
  final ValueChanged<NextScene> onStuck;
  final bool stuckPending;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LeftOff(finder: finder, onOpen: onOpen, onWrite: onWrite, onStuck: onStuck, stuckPending: stuckPending),
            const SizedBox(height: 32),
            const WordsSection(),
            const SizedBox(height: 32),
            const ManuscriptBand(),
            const SizedBox(height: 32),
            const LatestCat(),
          ],
        ),
      );
}
