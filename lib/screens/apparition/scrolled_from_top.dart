import 'package:flutter/foundation.dart';

/// Below this the header is at rest; above it, the reader is into the text.
const double _enter = 24;

/// Coming back, it takes rather less to be at the top again. The gap between
/// the two is the point: one threshold would flip the header back and forth
/// while a finger rests mid-scroll.
const double _leave = 8;

/// Whether a scroll view has left its top, as a boolean with hysteresis.
///
/// A boolean rather than the live offset, deliberately: what reads well is
/// one timed step between two sizes — the same thing the desktop does — and
/// a header interpolated per frame against the finger is busier, not
/// smoother. So this fires twice per journey instead of sixty times a second.
///
/// Knows nothing about headers: it answers a question about a scroll view.
class ScrolledFromTop extends ValueNotifier<bool> {
  ScrolledFromTop() : super(false);

  void onOffset(double y) {
    value = value ? y > _leave : y > _enter;
  }
}
