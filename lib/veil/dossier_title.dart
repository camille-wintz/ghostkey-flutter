/// A `## ` title started at [at] in [text]: on its own line, a blank line
/// above it unless it opens the text, one below it before any text that
/// follows. Answers the new text and where the caret goes — after the `## `,
/// so the author types the title next. The phone web's `insertDossierTitle`
/// (ghost-key src/mobile/rooms/veil/dossierTitle.ts).
({String text, int caret}) insertDossierTitle(String text, int at) {
  final cut = at.clamp(0, text.length);
  final before = text.substring(0, cut).replaceFirst(RegExp(r'[ \t]+$'), '');
  final after = text.substring(cut);
  final lead = before.isEmpty || before.endsWith('\n\n')
      ? ''
      : before.endsWith('\n')
          ? '\n'
          : '\n\n';
  final insert = '$lead## ';
  final tail = after.isEmpty || after.startsWith('\n') ? after : '\n\n$after';
  return (text: before + insert + tail, caret: before.length + insert.length);
}
