/// What the scan flow needs to know about its surroundings that the editor
/// does not carry: the chapter's title (for `Insert into <chapter>`) and the
/// project (so the server can spell the world bible's names right).
///
/// The caller sets these before launching `startScan`, typically wherever it
/// sets the active chapter:
///
/// ```dart
/// ScanContext.chapterTitle = chapter.title;
/// ScanContext.projectId = projectId;   // optional — falls back to ProjectScope
/// ```
///
/// A static registry rather than a widget scope because the flow is pushed
/// on the ROOT navigator, above the project's own scope. `projectId` may be
/// left null when the launching context sits under a `ProjectScope`.
abstract final class ScanContext {
  /// The chapter the text lands in, as the review's button names it. Null
  /// reads as "this chapter".
  static String? chapterTitle;

  /// The open project's id, for the OCR request's spelling hints.
  static String? projectId;

  static void clear() {
    chapterTitle = null;
    projectId = null;
  }
}
