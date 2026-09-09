import 'package:flutter/widgets.dart';

import 'editor_controller.dart';

/// Opens a capture surface (the dictation dock, the scan viewfinder) over the
/// page and lands what it captured in `editor`. Resolves when the surface has
/// closed.
typedef CaptureLauncher = Future<void> Function(BuildContext context, EditorController editor);

/// Where the editor's mic and camera reach. Unset by default: the room draws
/// the buttons dimmed until `main.dart` assigns the launchers, so the editor
/// never imports the capture code it hands its controller to.
abstract final class CaptureLaunchers {
  static CaptureLauncher? dictate;
  static CaptureLauncher? scan;
}
