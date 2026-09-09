import 'package:flutter/foundation.dart';

/// How tall the dictation dock is drawing, in logical pixels, or 0 when it is
/// not up. The dock is an overlay above the page, so the page cannot measure
/// it; the editor reads this to keep that much room free at its foot — the
/// manuscript stays scrollable while the session runs, and its last lines
/// must not sit under the dock. Grows by a notice, so it is measured, not
/// guessed.
final ValueNotifier<double> dictationDockHeight = ValueNotifier<double>(0);
