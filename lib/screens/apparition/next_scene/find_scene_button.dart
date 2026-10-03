import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../next_scene/next_scene_finder.dart';
import '../../../ui/press.dart';

/// "Find me a scene to write", as the small square beside the
/// where-you-left-off card: the same height, a compass over two short words.
/// The answer unfolds under both (`SceneAnswer`).
class FindSceneButton extends StatelessWidget {
  const FindSceneButton({super.key, required this.finder});
  final NextSceneFinder finder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: finder,
        builder: (context, _) => Press(
          onPressed: finder.start,
          enabled: !finder.pending,
          semanticLabel: 'Find me a scene to write',
          builder: (context, pressed) => AnimatedContainer(
            duration: DsMotion.duration,
            width: 84,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: pressed ? Ds.accentMix(12) : Ds.panel,
              borderRadius: BorderRadius.circular(DsGeom.radius),
              border: Border.all(color: pressed ? Ds.accent : Ds.edge),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: finder.pending
                      ? CircularProgressIndicator(strokeWidth: 1.5, color: Ds.accent)
                      : Icon(LucideIcons.compass, size: 18, color: Ds.accent),
                ),
                const SizedBox(height: 8),
                Text(
                  'Find a scene',
                  textAlign: TextAlign.center,
                  style: DsStyle.ui(DsText.eyebrow, color: Ds.mid, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
}
