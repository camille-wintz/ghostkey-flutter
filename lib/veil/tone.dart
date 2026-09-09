import 'package:flutter/painting.dart';

import '../ds/tokens.dart';
import '../server/dto/bible.dart';

/// One step of the accent ramp per entity type — the desktop's `TYPE_TONE`.
/// Characters, places and terms need to separate at a glance, but hue in
/// this app means state, never category, so they separate by lightness
/// along the one blue instead of picking three colours.
Color typeTone(BibleEntityType type) => switch (type) {
      BibleEntityType.character => Ds.accent300,
      BibleEntityType.place => Ds.accent,
      BibleEntityType.term => Ds.accent600,
    };
