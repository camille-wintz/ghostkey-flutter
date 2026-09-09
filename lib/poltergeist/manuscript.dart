/// A chapter filename from a title the author typed — the desktop's
/// `chapterFilename`: path separators become dashes, runs of dots collapse,
/// a leading dot goes, and `.md` is appended unless already there.
String chapterFilename(String title) {
  final safe = title
      .trim()
      .replaceAll(RegExp(r'[/\\]'), '-')
      .replaceAll(RegExp(r'\.{2,}'), '.')
      .replaceFirst(RegExp(r'^\.+'), '');
  final base = safe.isEmpty ? 'Untitled' : safe;
  return base.toLowerCase().endsWith('.md') ? base : '$base.md';
}
