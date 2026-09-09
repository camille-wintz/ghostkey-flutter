import 'package:flutter/painting.dart';

import '../ds/tokens.dart';
import '../server/dto/projects.dart';

/// What a chapter owes, as a colour. The hues are fixed across the suite
/// (`--color-plan-*`), so a chapter reads the same in Poltergeist's board and
/// in Apparition's list. A new kind the desktop adds reads here as no dot
/// rather than a wrong one.
class PlanMarker {
  const PlanMarker({required this.color, required this.label});
  final Color color;

  /// What the dot means, for the row's accessibility label.
  final String label;
}

Color planColor(PlanActionKind kind) => switch (kind) {
      PlanActionKind.write => Ds.planWrite,
      PlanActionKind.rewrite => Ds.planRewrite,
      PlanActionKind.lineEdit => Ds.planLine,
      // No hue: moving a chapter doesn't change a word of it.
      PlanActionKind.move => Ds.mid,
      PlanActionKind.delete => Ds.destructive,
    };

/// document id → marker. Work owed outranks the finished mark. A row with
/// neither, or one the plan has never linked to a document, gets nothing.
Map<String, PlanMarker> planMarkers(ProjectPlan? plan) {
  final markers = <String, PlanMarker>{};
  for (final chapter in plan?.chapters ?? const <PlanChapter>[]) {
    final documentId = chapter.documentId;
    if (documentId == null || documentId.isEmpty) continue;
    final kind = chapter.action;
    if (kind != null) {
      markers[documentId] = PlanMarker(color: planColor(kind), label: kind.label);
    } else if (chapter.done) {
      markers[documentId] = PlanMarker(color: Ds.done, label: 'Done');
    }
  }
  return markers;
}
