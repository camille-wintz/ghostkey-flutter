import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../server/client.dart';
import '../server/dto/transcribe.dart';
import '../server/errors.dart';
import 'policy.dart';

// Ships one finished chunk to POST /api/transcribe. Ported from
// ghostkey-mobile `src/audio/transcribe.ts`. Recording, metering and chunking
// happen locally; the provider keys and both pipelines live on the server.
//
// `projectId` has the server inject the project's world-bible spellings into
// its cleanup pass. `previous` is the manuscript just before the insertion
// point — what tells the pass whether a quotation is already open. `turns`
// is the session so far as `{verbatim, cleaned}` pairs; the Gemini pipeline
// reads it as the conversation this chunk continues, the legacy pipeline
// ignores it, so it is sent unconditionally.

/// What came back for one chunk. `verbatim` is the transcript the cleaned
/// text was diffed against — the session's next turn. Falls back to `text`
/// when the server's pipeline reports none.
class Transcript {
  const Transcript({required this.text, required this.verbatim});
  final String text;
  final String verbatim;
}

Future<Transcript> transcribeAudioChunk(
  String path, {
  String? projectId,
  String? previous,
  List<TranscriptTurn> turns = const [],
}) async {
  final bytes = await File(path).readAsBytes();
  final fields = <String, String>{
    'project_id': ?projectId,
    if (previous != null && previous.isNotEmpty) 'previous': previous,
    if (turns.isNotEmpty) 'turns': turnsJson(turns),
  };

  // A request that never answers must not hold the session: transcripts land
  // in spoken order, so one hung upload would queue every later chunk's text
  // behind it for the rest of the session — and keep the idle stop from ever
  // firing, since it waits for the in-flight count to reach zero. Same
  // headroom as the desktop client. The deadline covers the whole exchange,
  // body included; apiFetch's own `timeout` only covers the headers.
  final ApiResponse res;
  try {
    res = await apiFetch(
      '/api/transcribe',
      method: 'POST',
      fields: fields,
      files: [
        ApiFilePart(field: 'file', filename: 'chunk.m4a', bytes: bytes, contentType: 'audio/m4a'),
      ],
    ).timeout(const Duration(milliseconds: DictationPolicy.uploadTimeoutMs));
  } on TimeoutException {
    // Named, and kept network-shaped so the recorder's retry treats it as one.
    throw ServerError(
      'network_error',
      0,
      'POST /api/transcribe gave no answer within ${DictationPolicy.uploadTimeoutMs}ms',
    );
  }

  final data = TranscribeResponse.fromJson(res.jsonObject());
  // NOT trimmed. A chunk whose whole speech was a break command ("new line")
  // comes back as exactly "\n\n", and trimming turned it into "" — which the
  // recorder reads as a chunk that held no speech, so the paragraph the writer
  // asked for was dropped. Whitespace carrying no newline is still nothing to
  // insert. `verbatim` is context only, so it keeps its trim.
  final raw = data.text;
  final text = raw.trim().isEmpty && !raw.contains('\n') ? '' : raw;
  return Transcript(text: text, verbatim: (data.verbatim ?? text).trim());
}

/// The `turns` field: a JSON array of `{verbatim, cleaned}`, oldest first.
String turnsJson(List<TranscriptTurn> turns) => jsonEncode([for (final t in turns) t.toJson()]);
