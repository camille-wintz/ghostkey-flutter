import 'dart:async';
import 'dart:convert';

// A Server-Sent Events reader over a byte stream. Knows nothing about chat:
// it hands every `data:` payload to the caller as a string and stops at the
// `[DONE]` sentinel. `LineSplitter` owns the straddled-frame problem — a frame
// split across two chunks arrives whole.

const _done = '[DONE]';

/// Every `data:` payload of the stream, in order, ending at `[DONE]` or at the
/// end of the body. Comments (`:keepalive`), `event:` / `id:` fields and blank
/// separators carry nothing this consumer reads.
Stream<String> readSse(Stream<List<int>> body) async* {
  await for (final rawLine
      in body.transform(utf8.decoder).transform(const LineSplitter())) {
    final line = rawLine.endsWith('\r')
        ? rawLine.substring(0, rawLine.length - 1)
        : rawLine;
    if (!line.startsWith('data:')) continue;
    final payload = line.substring('data:'.length).trimLeft();
    if (payload == _done) return;
    if (payload.isNotEmpty) yield payload;
  }
}
