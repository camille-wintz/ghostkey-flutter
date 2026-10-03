import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';
import '../../../server/dto/next_scene.dart';
import '../../../ui/button.dart';
import '../../../ui/text.dart';

const _kindLabel = {
  NextSceneKind.unwritten: 'A chapter still to write',
  NextSceneKind.transition: 'A missing transition',
  NextSceneKind.continue_: 'What comes next',
};

/// The scene the finder came back with: where, the prompt, and the author's
/// answers to it — write it, think it through, or pass it for the next spot.
class SceneSuggestion extends StatelessWidget {
  const SceneSuggestion({
    super.key,
    required this.scene,
    required this.onWrite,
    required this.onStuck,
    required this.stuckPending,
    this.onNextSpot,
  });
  final NextScene scene;
  final VoidCallback onWrite;
  final VoidCallback onStuck;
  final bool stuckPending;
  final VoidCallback? onNextSpot;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Ds.panel,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(_kindLabel[scene.kind]!, color: Ds.low),
              const SizedBox(height: 8),
              Text(scene.headline, style: DsStyle.prose(DsText.prose, color: Ds.hi)),
              const SizedBox(height: 8),
              Text(scene.prompt, style: DsStyle.prose(DsText.body, color: Ds.mid)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GkButton(label: "Let's write", onPressed: onWrite),
                  GkButton(label: "I'm stuck", variant: ButtonVariant.outline, busy: stuckPending, onPressed: onStuck),
                  if (onNextSpot case final next?)
                    GkButton(label: 'Next spot', variant: ButtonVariant.outline, onPressed: next),
                ],
              ),
            ],
          ),
        ),
      );
}
