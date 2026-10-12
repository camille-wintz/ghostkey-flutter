import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/media/note_pieces.dart';

void main() {
  test('a short note is one piece', () {
    expect(cutNote('a' * 100), [(start: 0, end: 100)]);
  });

  test('a long run is cut at a line break, and the pieces cover the body', () {
    final body = '${'a' * 30}\n${'b' * 30}\n${'c' * 30}';
    final pieces = cutNote(body, maxChars: 40);
    expect(pieces.first, (start: 0, end: 31));
    expect(pieces.last.end, body.length);
    for (var i = 1; i < pieces.length; i++) {
      expect(pieces[i].start, pieces[i - 1].end);
    }
  });

  test('a cut with no line break never splits a surrogate pair', () {
    final body = '${'a' * 9}😀${'a' * 9}';
    final pieces = cutNote(body, maxChars: 10);
    expect(pieces.first.end, 9);
    expect(pieces.map((p) => body.substring(p.start, p.end)).join(), body);
  });
}
