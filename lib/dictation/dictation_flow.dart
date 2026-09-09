import 'dart:async';

import 'package:flutter/material.dart';

import '../ds/tokens.dart';
import '../editor/editor_controller.dart';
import '../screens/project/project_root.dart';
import '../server/errors.dart';
import '../ui/notice_modal.dart';
import 'anchor.dart';
import 'dock/record_dock.dart';
import 'session.dart';

// The entry point the editor's mic button calls (a `CaptureLauncher`).
//
// Opens the dock as an overlay pinned above the keyboard inset, takes the
// insertion point from the caret, locks the editor for the session, runs the
// recorder, and lands every transcript at that point — mapped through
// whatever else changes the text — with the join and typography rules of
// the RN app (anchor.dart). Resolves when the dock closes; chunks still in
// flight keep landing after that, at the point, and the session is disposed
// once the last one has.

Future<void> startDictation(BuildContext context, EditorController editor) async {
  final projectId = ProjectScope.of(context);
  final overlay = Overlay.of(context, rootOverlay: true);

  final anchor = DictationAnchor(editor)..open();
  editor.readOnly = true;

  late final DictationSession session;
  late final OverlayEntry entry;
  final closed = Completer<void>();

  Future<void> close() async {
    if (closed.isCompleted) return;
    closed.complete();
    entry.remove();
    editor.readOnly = false;
    await session.stop();
  }

  session = DictationSession(
    projectId: projectId,
    onTranscript: anchor.insertDictation,
    previousText: anchor.textBeforeDictation,
    // A plan refusal refuses every chunk: close the dock and say so once.
    onRefused: (ServerError e) {
      unawaited(close());
      if (context.mounted) {
        unawaited(showNoticeModal(
          context,
          eyebrow: 'Dictation',
          title: messageFor(e),
          action: 'OK',
          children: const [],
        ));
      }
    },
  );

  entry = OverlayEntry(
    builder: (context) => _DockHost(child: RecordDock(session: session, onDone: () => unawaited(close()))),
  );
  overlay.insert(entry);

  await session.start();
  await closed.future;

  unawaited(session.drained.whenComplete(() {
    anchor.dispose();
    session.dispose();
  }));
}

/// Pins the dock to the bottom of the screen, above the keyboard when one is
/// up — tapping into the text raises it, and a dock under the keyboard would
/// take the waveform, the clock and Done with it. Arrives on the house's
/// screen-in fade.
class _DockHost extends StatelessWidget {
  const _DockHost({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: inset,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: DsMotion.screenIn,
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 24), child: child),
        ),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}
