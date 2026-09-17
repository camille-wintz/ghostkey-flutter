// A chapter as a report names it. Reports carry the chapter's filename; an
// author never typed the extension, and a numbered filename reads better as
// "Chapter 3" over its name. The desk's `reverse-outline/chapterTitle.ts`.

final RegExp _extension = RegExp(r'\.md$', caseSensitive: false);

/// The filename without `.md`.
String chapterLabel(String filename) => filename.replaceAll(_extension, '');

/// "Chapter n", the readable name when the filename has one beyond its
/// number, and the filename it came from.
({String label, String? title, String source}) chapterTitle(String filename, int index) {
  final source = chapterLabel(filename);
  final readable = source
      .replaceFirst(RegExp(r'^[\d._\-\s]+'), '')
      .replaceFirst(RegExp(r'^chapter[\s._-]*\d*[\s._-]*', caseSensitive: false), '')
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return (label: 'Chapter ${index + 1}', title: readable.isEmpty ? null : readable, source: source);
}
