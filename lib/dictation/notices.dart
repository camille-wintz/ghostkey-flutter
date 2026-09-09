import 'background_mode.dart';
import 'policy.dart';

// What the dock says. Ported from ghostkey-mobile `RecordOverlay.tsx`.

/// Something the writer must know about the session: words that did not make
/// it, or why the mic stopped listening. `error` is a loss that already
/// happened; `warning` is a pause they can undo.
enum NoticeKind { warning, error }

class DockNotice {
  const DockNotice(this.kind, this.text);
  final NoticeKind kind;
  final String text;
}

/// The session ended itself. The dock stays, paused, and says why: a dock
/// that had vanished by the time the phone was unlocked read as "the mic was
/// on and dropped what I said". Play resumes.
DockNotice autoStopNotice(AutoStopReason reason) => DockNotice(
      NoticeKind.warning,
      switch (reason) {
        AutoStopReason.idle => 'Paused: nothing was heard for five minutes. Tap play to keep dictating.',
        AutoStopReason.ceiling => 'Paused at the one-hour limit. Tap play to keep dictating.',
        AutoStopReason.locked =>
          'Paused when the screen locked. Allow notifications for Ghostkey to keep dictating with the screen off.',
        AutoStopReason.stopped => 'Stopped from the notification. Tap play to keep dictating.',
      },
    );

/// The session is on, but only while the screen is: said up front rather
/// than after the first lock has eaten a sentence.
DockNotice foregroundOnlyNotice(ForegroundOnlyReason reason) => DockNotice(
      NoticeKind.warning,
      switch (reason) {
        ForegroundOnlyReason.notificationsDenied =>
          'Dictation will pause when the screen locks. Allow notifications for Ghostkey in Settings to keep it going.',
        ForegroundOnlyReason.noService => 'Dictation will pause when the screen locks in this build.',
      },
    );

/// A chunk that could not be transcribed after its retries. One notice, the
/// latest — an alert per chunk stacked a modal for every chunk a dead network
/// dropped, on a phone that may have been in a pocket.
DockNotice lostChunkNotice(String why) =>
    DockNotice(NoticeKind.error, "A passage couldn't be transcribed and was lost. $why");

const DockNotice microphoneDeniedNotice =
    DockNotice(NoticeKind.error, 'Ghostkey needs the microphone to dictate. Allow it in Settings and tap play.');

DockNotice recorderFailedNotice(String why) =>
    DockNotice(NoticeKind.error, 'The recorder stopped. $why Tap play to try again.');
