import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../server/dto/next_scene.dart';
import '../../../ui/menu_sheet.dart';
import '../../../ui/press.dart';
import '../../../next_scene/next_scene_finder.dart';
import 'scene_suggestion.dart';

/// What "Find me a scene to write" came back with, unfolded under the
/// where-you-left-off card it sits beside (the desk's `ResumeWriting`): the
/// scene and the author's answers to it, or a way to ask again.
class SceneAnswer extends StatelessWidget {
  const SceneAnswer({super.key, required this.finder, required this.onWrite, required this.onStuck, required this.stuckPending});
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
              if (finder.pending)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Reading where your chapters meet…', style: DsStyle.ui(DsText.ui, color: Ds.low)),
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
        padding: const EdgeInsets.only(top: 12),
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
