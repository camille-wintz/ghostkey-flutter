import '../core/words.dart';

// The composer's half of chat attachments: the paste rule and how a handle is
// minted. What the model is shown, and when a body is inlined versus stubbed,
// is the server's (ghostkey-server lib/chat/attachments.ts). Mirrors the RN
// app's src/chat/attachments.ts.

/// A paste at or above this many words becomes an attachment instead of
/// message text: message text is re-sent on every later turn, an attachment
/// is inlined once and re-read only on demand.
const int pasteAttachmentMinWords = 250;

/// Hard ceiling on one paste's text. The server caps a whole transcript at
/// 1 MiB and a session over it silently stops saving.
const int pasteAttachmentMaxChars = 100000;

bool isLongPaste(String text) => countWords(text) >= pasteAttachmentMinWords;

/// The next unused handle — short ("a1", "a7") because the model types it
/// back, unique across the session because that is the server's scope.
String mintAttachmentId(Iterable<String> used) {
  final taken = used.toSet();
  for (var n = 1;; n++) {
    final id = 'a$n';
    if (!taken.contains(id)) return id;
  }
}

final RegExp _whitespaceRun = RegExp(r'\s+');

/// Name a paste after its first non-empty line — usually a heading or the
/// opening sentence, which the author will recognise on a chip.
String pasteTitle(String text) {
  final firstLine = text.split('\n').map((l) => l.trim()).firstWhere((l) => l.isNotEmpty, orElse: () => '');
  if (firstLine.isEmpty) return 'Pasted text';
  final oneLine = firstLine.replaceAll(_whitespaceRun, ' ');
  return oneLine.length > 48 ? '${oneLine.substring(0, 48).trimRight()}…' : oneLine;
}

/// A paste past the ceiling is kept, truncated and marked — better than a
/// conversation that silently stops persisting.
String capPasteText(String text) {
  if (text.length <= pasteAttachmentMaxChars) return text;
  return '${text.substring(0, pasteAttachmentMaxChars)}\n\n[…truncated — the paste was too long to keep in full]';
}

final RegExp _mdSuffix = RegExp(r'\.md$', caseSensitive: false);

String stripMd(String filename) => filename.replaceAll(_mdSuffix, '');

/// The run of text one edit inserted, and the text with that run taken back
/// out. A paste is recognised by its size: a single change that adds a
/// chapter's worth of words is not typing. `start` is where the run began, so
/// the caret can be put back there. Null when the change removed text or
/// inserted nothing.
({String inserted, String without, int start})? insertedRun(String previous, String next) {
  if (next.length <= previous.length) return null;
  final max = previous.length;
  var start = 0;
  while (start < max && previous.codeUnitAt(start) == next.codeUnitAt(start)) {
    start++;
  }
  var end = 0;
  while (end < max - start &&
      previous.codeUnitAt(previous.length - 1 - end) == next.codeUnitAt(next.length - 1 - end)) {
    end++;
  }
  final inserted = next.substring(start, next.length - end);
  if (inserted.isEmpty) return null;
  return (
    inserted: inserted,
    without: previous.substring(0, start) + previous.substring(previous.length - end),
    start: start,
  );
}
