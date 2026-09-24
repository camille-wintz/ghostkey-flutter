import 'package:flutter/foundation.dart';

import 'recorder_channel.dart';

// Whether a dictation session may keep the microphone open with the screen
// off. Ported from ghostkey-mobile `src/audio/backgroundRecording.ts`.
//
// Android 13+ makes the recording notification the gate: the foreground
// service runs without POST_NOTIFICATIONS, but the OS shows nothing for it,
// and a microphone nobody can see or stop is not a session to run under
// lock. A writer who taps that prompt away must still be able to dictate, so
// a denial degrades the session to foreground-only rather than refusing it
// (docs/background-recording-plan.md §3.B, decided 2026-09-06).

enum BackgroundMode { background, foreground }

Future<BackgroundMode> chooseBackgroundMode(NativeRecorder recorder) async {
  if (!defaultTargetPlatform.isAndroid) return BackgroundMode.background;
  try {
    final perms = await recorder.permissions();
    if (perms.sdk < 33) return BackgroundMode.background;
    final granted = perms.notifications || await recorder.requestNotifications();
    return granted ? BackgroundMode.background : BackgroundMode.foreground;
  } catch (e) {
    debugPrint('[dictation] notification permission request failed: $e');
    return BackgroundMode.foreground;
  }
}

extension on TargetPlatform {
  bool get isAndroid => this == TargetPlatform.android;
}
