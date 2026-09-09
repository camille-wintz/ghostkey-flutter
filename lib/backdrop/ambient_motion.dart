import 'package:flutter/widgets.dart';

/// Whether the decorative layers should be moving right now: not when the
/// phone has asked for less movement, and not when the route holding them is
/// under another one — an animation ticking for a backdrop nobody is
/// compositing is exactly the thread that must not stutter while someone
/// types in the room on top.
bool ambientMotion(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) return false;
  final route = ModalRoute.of(context);
  return route == null || route.isCurrent;
}
