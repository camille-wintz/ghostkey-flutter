import 'dart:ui';

import '../../../ds/tokens.dart';
import '../../../mara/proposal.dart';

/// Hue is state: settled for a chapter the book already has, attention for
/// one the outline never asked for, the accent for one still to write.
Color statusColor(ChapterStatus status) => switch (status) {
      ChapterStatus.written => Ds.done,
      ChapterStatus.kept => Ds.attention,
      ChapterStatus.fresh => Ds.accent,
    };
