// Frame accounting for the chunk seam. The native recorder encodes a session
// as ONE stream of 1024-sample AAC access units and cuts it into files at AU
// boundaries; every chunk reports the AU range it holds. If consecutive
// chunks meet exactly and the AUs written cover the samples fed, no audio was
// lost between chunk N and N+1 — which is the whole point of the port
// (../ghostkey-mobile/docs/flutter-port-plan.md, P2). Pure and tested; the
// session logs what it finds in debug builds.

/// Samples per AAC-LC access unit, per channel. Fixed by the codec.
const int aacFrameSamples = 1024;

class SeamGap {
  const SeamGap({required this.afterIndex, required this.expectedStart, required this.actualStart});

  /// The chunk index the gap follows.
  final int afterIndex;
  final int expectedStart;
  final int actualStart;

  /// Positive: frames missing between the two files. Negative: frames doubled.
  int get frames => actualStart - expectedStart;

  @override
  String toString() => 'SeamGap(after chunk $afterIndex: expected $expectedStart, got $actualStart)';
}

class SeamLedger {
  final List<({int index, int startFrame, int endFrame})> _chunks = [];

  int get chunkCount => _chunks.length;

  /// Frames across every chunk recorded so far.
  int get framesCovered => _chunks.fold(0, (sum, c) => sum + (c.endFrame - c.startFrame));

  void add({required int index, required int startFrame, required int endFrame}) {
    _chunks.add((index: index, startFrame: startFrame, endFrame: endFrame));
  }

  /// Every pair of consecutive chunks that does not meet exactly.
  List<SeamGap> gaps() {
    final sorted = [..._chunks]..sort((a, b) => a.index.compareTo(b.index));
    final out = <SeamGap>[];
    for (var i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final cur = sorted[i];
      if (cur.startFrame != prev.endFrame) {
        out.add(SeamGap(afterIndex: prev.index, expectedStart: prev.endFrame, actualStart: cur.startFrame));
      }
    }
    return out;
  }

  /// Whether the frames written cover the samples fed (the encoder pads the
  /// last frame, so written × 1024 is at least the input) and the files
  /// account for every frame written.
  bool covers({required int samplesIn, required int framesOut}) =>
      framesOut * aacFrameSamples >= samplesIn && framesCovered == framesOut;

  /// One line for the log, or null when the seam is clean.
  String? report({required int samplesIn, required int framesOut}) {
    final g = gaps();
    final ok = covers(samplesIn: samplesIn, framesOut: framesOut);
    if (g.isEmpty && ok) return null;
    final parts = <String>[
      if (g.isNotEmpty) '${g.length} gap(s): ${g.join('; ')}',
      if (!ok) 'coverage: $framesCovered/$framesOut frames written for $samplesIn samples',
    ];
    return 'seam not clean — ${parts.join(' — ')}';
  }
}
