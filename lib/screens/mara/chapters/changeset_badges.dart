import 'dart:ui';

import '../../../ds/tokens.dart';
import '../../../server/dto/plan.dart';

/// Hue is state: red for a chapter about to go, amber for one about to be
/// retold, the accent for one about to be added.
({String label, Color color}) opBadge(ChangesetOp op) => switch (op) {
      ChangesetRemove() => (label: 'removed', color: Ds.destructive),
      ChangesetRewrite() => (label: 'rewritten', color: Ds.attention),
      ChangesetAdd() => (label: 'new', color: Ds.accent),
    };
