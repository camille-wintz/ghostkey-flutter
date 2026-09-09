import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../server/bible/api.dart';
import '../../server/dto/bible.dart';

/// How long after the last landed save the chapter is swept again. Every
/// save bumps the document's version, and the server's cache is keyed by it,
/// so a sweep per save would be a model call every five seconds of typing —
/// against the name-suggestions allowance. A sweep once the writer has been
/// quiet for this long tracks writing sittings rather than keystrokes.
const Duration rescanAfterSave = Duration(seconds: 60);

/// The open chapter's unfiled names, and the filing of them.
///
/// The sweep runs on chapter OPEN, which is the only moment it is worth
/// anything — the author is looking at the words the names are in. Firing
/// it automatically is safe because the server caches per chapter version:
/// a chapter nobody has edited since its last sweep costs no model call.
///
/// A sweep that fails costs the author nothing to not have: the banner is
/// simply absent. Retrying an answer the model already refused would spend
/// the same money to reach the same place.
class NamesSweep {
  NamesSweep({required this.projectId, required this.documentId});

  final String projectId;
  final String documentId;

  final ValueNotifier<List<NameCandidate>> candidates = ValueNotifier(const []);

  /// The name currently being written, so its row can go quiet on its own
  /// without locking the others.
  final ValueNotifier<String?> filing = ValueNotifier(null);

  Timer? _rescan;
  bool _scanning = false;
  bool _disposed = false;

  Future<void> scan() async {
    if (_scanning || _disposed) return;
    _scanning = true;
    try {
      final res = await scanChapterNames(projectId, documentId);
      if (_disposed) return;
      candidates.value = res.candidates;
    } catch (e) {
      debugPrint('[names] sweep skipped: $e');
    } finally {
      _scanning = false;
    }
  }

  /// A save landed: sweep again once the writer has gone quiet.
  void scheduleRescan() {
    _rescan?.cancel();
    _rescan = Timer(rescanAfterSave, () => unawaited(scan()));
  }

  /// File one name — accept, or decline as a hidden entity. Either way the
  /// server filters it out of the next sweep, so it is dropped here at once
  /// rather than paying a round trip to prove it. Throws on refusal.
  Future<void> file(NameCandidate candidate, {required bool hidden}) async {
    filing.value = candidate.name;
    try {
      await createBibleEntity(projectId, type: candidate.type, name: candidate.name, hidden: hidden);
      if (_disposed) return;
      candidates.value = candidates.value.where((c) => c.name != candidate.name).toList();
    } finally {
      if (!_disposed) filing.value = null;
    }
  }

  void dispose() {
    _disposed = true;
    _rescan?.cancel();
    candidates.dispose();
    filing.dispose();
  }
}
