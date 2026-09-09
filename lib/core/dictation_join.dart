// Where a dictated chunk meets the text already written.
//
// A chunk is cut where the writer paused for breath, which is not where their
// sentences end — so the pass that cleaned the chunk BEFORE this one could not
// know whether its last sentence was finished, and left it open. The server
// hands the mark forward at the head of the next chunk (`. `, `? `, `! `), and
// the client puts it where it belongs: on a WORD, and only on a word that
// carries no punctuation of its own.

final RegExp _closingMark = RegExp(r'^([.!?])[^\S\n]*');
final RegExp _endsInWord = RegExp(r'[\p{L}\p{N}]$', unicode: true);

class ClosingMarkSplit {
  const ClosingMarkSplit(this.mark, this.body);
  final String mark;
  final String body;
}

/// Split a landing chunk into the mark that belongs to the text before it and
/// the chunk proper. `head` is that text with its trailing whitespace already
/// removed. An empty mark is the ordinary case, and the answer whenever the
/// mark would be wrong: nothing before it, or something already punctuating
/// it.
ClosingMarkSplit splitClosingMark(String head, String chunk) {
  final m = _closingMark.firstMatch(chunk);
  if (m == null) return ClosingMarkSplit('', chunk);
  final body = chunk.substring(m.end);
  return ClosingMarkSplit(_endsInWord.hasMatch(head) ? m.group(1)! : '', body);
}
