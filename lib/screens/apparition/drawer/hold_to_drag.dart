import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// How long a finger rests on a row before it lifts.
///
/// Short, because the hold is dead time twice over: nothing moves during it,
/// and Flutter's own lift animation only starts once it is up. Well under the
/// platform's 500ms long press and still long enough that a flick down the
/// list is a scroll — the recogniser fails the drag the moment the finger
/// travels, so the risk of going lower is a lift on a slow scroll, not on a
/// fast one.
const Duration liftDelay = Duration(milliseconds: 200);

/// A row that lifts after [liftDelay] — Flutter's own delayed drag start,
/// with the house's hold rather than the platform's 500ms long press.
class HoldToDrag extends ReorderableDragStartListener {
  const HoldToDrag({super.key, required super.child, required super.index, super.enabled});

  @override
  MultiDragGestureRecognizer createRecognizer() => DelayedMultiDragGestureRecognizer(delay: liftDelay, debugOwner: this);
}
