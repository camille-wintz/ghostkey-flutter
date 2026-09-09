import 'package:flutter/material.dart';

import '../editor/editor_controller.dart';
import '../screens/project/project_root.dart';
import 'ocr_insert.dart';
import 'scan_context.dart';
import 'scan_route.dart';

// The editor's "scan a page" launcher (a `CaptureLauncher`): pushes the
// viewfinder → review flow as a full-screen route on the ROOT navigator, and
// when the author presses "Insert", lands the reviewed text in the chapter.
//
// The landing point is the caret the editor had when the flow opened — an
// author who tapped the camera mid-sentence gets the page there, not
// wherever a stray selection change left the field. If the text changed
// while the flow was up (dictation landing, a sync), that caret is stale and
// the current one is used instead.
//
// Before launching, the caller sets `ScanContext.chapterTitle` (and
// optionally `ScanContext.projectId`; otherwise the enclosing `ProjectScope`
// supplies it) — see scan_context.dart.

Future<void> startScan(BuildContext context, EditorController editor) async {
  if (editor.readOnly) return;

  final textAtOpen = editor.text;
  final selectionAtOpen = editor.selection;
  final projectId =
      ScanContext.projectId ?? context.getInheritedWidgetOfExactType<ProjectScope>()?.projectId;
  final chapterTitle = ScanContext.chapterTitle?.trim();

  final result = await Navigator.of(context, rootNavigator: true).push<String>(
    MaterialPageRoute<String>(
      fullscreenDialog: true,
      builder: (context) => ScanRoute(
        chapterTitle: chapterTitle == null || chapterTitle.isEmpty ? 'this chapter' : chapterTitle,
        projectId: projectId,
      ),
    ),
  );
  if (result == null || result.trim().isEmpty || editor.readOnly) return;

  final selection = editor.text == textAtOpen ? selectionAtOpen : editor.selection;
  final plan = planOcrInsert(
    document: editor.text,
    selection: selection,
    chunk: result,
    mode: editor.typography,
  );
  if (plan.isCollapsed) {
    editor.insertAt(plan.start, plan.text);
  } else {
    editor.replaceRange(plan.start, plan.end, plan.text);
  }
}
