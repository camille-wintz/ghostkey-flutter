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

/// Why a session is foreground-only: the notification was refused, or this
/// build/OS has no service to post one.
enum ForegroundOnlyReason { notificationsDenied, noService }

class BackgroundChoice {
  const BackgroundChoice.background()
      : mode = BackgroundMode.background,
        reason = null;
  const BackgroundChoice.foreground(this.reason) : mode = BackgroundMode.foreground;
  final BackgroundMode mode;
  final ForegroundOnlyReason? reason;
}

Future<BackgroundChoice> chooseBackgroundMode(NativeRecorder recorder) async {
  if (!defaultTargetPlatform.isAndroid) return const BackgroundChoice.background();
  try {
    final perms = await recorder.permissions();
    if (perms.sdk < 33) return const BackgroundChoice.background();
    final granted = perms.notifications || await recorder.requestNotifications();
    return granted
        ? const BackgroundChoice.background()
        : const BackgroundChoice.foreground(ForegroundOnlyReason.notificationsDenied);
  } catch (e) {
    debugPrint('[dictation] notification permission request failed: $e');
    return const BackgroundChoice.foreground(ForegroundOnlyReason.notificationsDenied);
  }
}

extension on TargetPlatform {
  bool get isAndroid => this == TargetPlatform.android;
}
