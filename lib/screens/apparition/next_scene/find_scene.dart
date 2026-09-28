import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../server/dto/next_scene.dart';
import '../../../ui/menu_sheet.dart';
import '../../../ui/page_row.dart';
import '../../../ui/press.dart';
import '../../../next_scene/next_scene_finder.dart';
import 'scene_suggestion.dart';

/// The row's height at rest — the list opens scrolled to the last chapter, and
/// counts this block in as a fixed band above the Chapters header.
const double findSceneRowHeight = 72;

/// "Find me a scene to write" above the chapters (the desk's `ResumeWriting`,
/// less "Open my previous spot": the phone's list already opens on the chapter
/// the author was last in, marked). The row asks; the answer unfolds under it.
class FindScene extends StatelessWidget {
  const FindScene({super.key, required this.finder, required this.onWrite, required this.onStuck, required this.stuckPending});
  final NextSceneFinder finder;
  final ValueChanged<NextScene> onWrite;
  final ValueChanged<NextScene> onStuck;
  final bool stuckPending;

  Future<void> _nextSpot(BuildContext context, NextScene scene) async {
    final pass = await showMenuSheet<SpotPass>(
      context,
      title: 'Keep suggesting this spot?',
      entries: const [
        MenuEntry(icon: LucideIcons.repeat, label: 'Keep suggesting', value: SpotPass.keep),
        MenuEntry(icon: LucideIcons.clock, label: 'Mark for later', value: SpotPass.later),
        MenuEntry(icon: LucideIcons.ban, label: 'Stop suggesting', value: SpotPass.never),
      ],
    );
    if (pass != null) await finder.pass(scene, pass);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: finder,
        builder: (context, _) {
          final scene = finder.scene;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: findSceneRowHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Opacity(
                    opacity: finder.pending ? 0.6 : 1,
                    child: PageRow(
                      icon: LucideIcons.compass,
                      label: 'Find me a scene to write',
                      description: "Let's avoid decision fatigue today.",
                      status: finder.pending ? 'Reading where your chapters meet…' : null,
                      onOpen: finder.pending ? () {} : finder.start,
                    ),
                  ),
                ),
              ),
              if (finder.error != null && !finder.pending) _Retry(onRetry: finder.retry),
              if (scene != null)
                SceneSuggestion(
                  scene: scene,
                  onWrite: () => onWrite(scene),
                  onStuck: () => onStuck(scene),
                  stuckPending: stuckPending,
                  // The end of the book is where every pass leads; there is no
                  // spot after it to move on to.
                  onNextSpot: scene.kind == NextSceneKind.continue_ ? null : () => _nextSpot(context, scene),
                ),
            ],
          );
        },
      );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Row(
          children: [
            Text("Couldn't find a scene just now. ", style: DsStyle.ui(DsText.ui, color: Ds.mid)),
            Press(
              onPressed: onRetry,
              semanticLabel: 'Try again',
              hitSlop: 10,
              builder: (context, pressed) =>
                  Text('Try again', style: DsStyle.ui(DsText.ui, color: pressed ? Ds.hi : Ds.accent)),
            ),
          ],
        ),
      );
}
