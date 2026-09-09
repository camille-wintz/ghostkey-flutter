import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'policy.dart';

// The recorder writes each chunk to `<cache>/dictation/<session>-<n>.m4a`
// and the session deletes it once it has been transcribed (or judged
// silent). A process kill mid-session — the writer force-stopping the app, a
// vendor battery manager — leaves the chunk in flight behind. Its audio
// cannot be replayed into the manuscript (the insertion anchor died with the
// session), so the next launch deletes it; the count is logged so a field
// report of "it stopped in my pocket" comes with a number. Ported from
// ghostkey-mobile `src/audio/orphanedRecordings.ts`.
//
// Call once per launch (the app root's initState); it never throws.

const String chunkDirectoryName = 'dictation';

Future<int> sweepOrphanedRecordings() async {
  try {
    final cache = await getTemporaryDirectory();
    final dir = Directory('${cache.path}/$chunkDirectoryName');
    if (!await dir.exists()) return 0;
    final cutoff = DateTime.now().subtract(DictationPolicy.orphanAge);
    var removed = 0;
    await for (final entry in dir.list()) {
      if (entry is! File || !entry.path.endsWith('.m4a')) continue;
      final stat = await entry.stat();
      // Younger than the cutoff and a live session may still own it (a hot
      // restart mid-chunk is the case the guard exists for).
      if (stat.modified.isAfter(cutoff)) continue;
      try {
        await entry.delete();
        removed += 1;
      } catch (_) {
        // Someone else's handle; the next launch gets it.
      }
    }
    if (removed > 0) debugPrint('[dictation] swept $removed orphaned chunk file(s) from a killed session');
    return removed;
  } catch (e) {
    debugPrint('[dictation] orphan sweep failed: $e');
    return 0;
  }
}
