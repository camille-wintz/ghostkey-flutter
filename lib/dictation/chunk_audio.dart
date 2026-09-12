import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'erase_silence.dart';
import 'policy.dart';
import 'recorder_channel.dart';

// What happens to a finished chunk between the recorder closing its file and
// the upload: the audio is read, judged, and either dropped, sent as
// recorded, or sent with its silence taken out (erase_silence.dart).
//
// It runs here rather than inside the recording loop so a long chunk's
// decode never delays the next chunk's cut, and before the retry loop so a
// chunk that retries through a network blip is not analysed three times.

/// The audio one chunk will be uploaded as.
class ChunkPayload {
  const ChunkPayload({required this.bytes, required this.filename, required this.contentType});
  final Uint8List bytes;
  final String filename;
  final String contentType;
}

/// The verdict on one chunk.
class PreparedChunk {
  const PreparedChunk({this.payload, this.floor = 0, this.removedMs = 0, this.dropped});

  /// What to upload, or null to drop the chunk without a round trip or the
  /// charge.
  final ChunkPayload? payload;

  /// This chunk's measured noise floor, to pool into the session's estimate.
  /// Reported for a dropped chunk too — a chunk that turned out to be nothing
  /// but room is the cleanest reading of that room the session will get. 0
  /// when no reading could be taken, which is not a reading of silence.
  final double floor;

  final int removedMs;

  /// Why it was dropped, for the log. Null when it was not.
  final String? dropped;
}

/// Read, judge and (where it helps) rebuild one finished chunk file.
///
/// [sessionFloor] is [sessionFloorOf] over the floors of this take's recent
/// chunks; null on the first chunk, where there is nothing to compare to yet.
Future<PreparedChunk> prepareChunk(
  String path, {
  double? sessionFloor,
  NativeRecorder? recorder,
}) async {
  final file = File(path);
  final Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (e) {
    return PreparedChunk(dropped: 'its file could not be read ($e)');
  }

  // A cheap pre-filter on the way to the decoder, which answers the same
  // question properly off the decoded duration. Bytes are only ever a hint —
  // the case this catches is a container and nothing else, an `.m4a` header
  // whose audio track never got a frame.
  if (bytes.length < DictationPolicy.minChunkBytes) {
    return PreparedChunk(dropped: 'it holds ${bytes.length} bytes — no recording in it');
  }

  final decoded = await (recorder ?? NativeRecorder()).decodePcm(path);
  if (decoded == null) {
    // Fails CLOSED, unlike every other judgement in this pass: audio the
    // decoder could not read holds no words to protect, and the model
    // invents over it rather than returning nothing. See erase_silence.dart.
    return PreparedChunk(dropped: 'its audio could not be decoded');
  }

  final Int16List samples;
  try {
    final raw = await File(decoded.path).readAsBytes();
    // Written little-endian by the decoder, which is every device this runs
    // on, so the view is free.
    samples = raw.buffer.asInt16List(raw.offsetInBytes, raw.lengthInBytes ~/ 2);
  } catch (e) {
    return PreparedChunk(dropped: 'its decoded audio could not be read ($e)');
  } finally {
    unawaited(_discard(decoded.path));
  }

  final erased = eraseSilence(samples, decoded.sampleRate, sessionFloor: sessionFloor);
  if (!erased.speech) {
    return PreparedChunk(floor: erased.floor, dropped: 'nothing in it stood above its own noise floor');
  }
  final wav = erased.wav;
  return PreparedChunk(
    floor: erased.floor,
    removedMs: erased.removedMs,
    payload: wav == null
        ? ChunkPayload(bytes: bytes, filename: 'chunk.m4a', contentType: 'audio/m4a')
        : ChunkPayload(bytes: wav, filename: 'chunk.wav', contentType: 'audio/wav'),
  );
}

Future<void> _discard(String path) async {
  try {
    await File(path).delete();
  } catch (_) {
    // Already gone, or the orphan sweep's on the next launch.
  }
}
