import 'package:flutter/foundation.dart';

import '../server/dto/next_scene.dart';
import '../server/projects/api.dart';

/// What the author said when passing a spot with "Next spot": [keep] passes
/// it for this round only; [later] and [never] are stored marks (the server's
/// back of the queue, and retired).
enum SpotPass { keep, later, never }

/// The prompt the author took with "Let's write", kept for the chapter it sent
/// them to — so the question doesn't vanish the moment its page opens.
typedef SceneBrief = ({String documentId, String headline, String prompt});

/// "Find me a scene to write" at the top of the chapter list — the desk's
/// `useNextScene`. [start] asks the server for a scene; [pass] passes the one
/// shown and asks for the one after, every spot passed this round riding
/// along as `skip`, and a `later`/`never` stored first so it holds on the next
/// visit too. [start] begins a fresh round.
///
/// Held by the room, like the list's own state: a chapter opened from the
/// suggestion and closed again comes back to the suggestion as it was left.
class NextSceneFinder extends ChangeNotifier {
  NextSceneFinder({required this.projectId});
  final String projectId;

  bool _pending = false;
  Object? _error;
  NextScene? _scene;
  List<String> _skipped = const [];
  ({List<String> skip, SpotMark? mark, String? spot})? _last;
  SceneBrief? _brief;

  /// A newer ask supersedes one still in flight.
  int _seq = 0;

  bool get pending => _pending;
  Object? get error => _error;

  /// The scene shown — none while an ask is out, or after one failed.
  NextScene? get scene => _pending ? null : _scene;

  /// The prompt "Let's write" took along, until the author closes it.
  SceneBrief? get brief => _brief;

  Future<void> start() {
    _skipped = const [];
    return _find(skip: const []);
  }

  Future<void> pass(NextScene scene, SpotPass pass) {
    // Passed this round whatever the answer: a spot just sent "for later"
    // shouldn't come straight back because nothing else is left.
    _skipped = [..._skipped, scene.spot];
    return _find(
      skip: _skipped,
      mark: switch (pass) { SpotPass.keep => null, SpotPass.later => SpotMark.later, SpotPass.never => SpotMark.never },
      spot: scene.spot,
    );
  }

  /// The last ask again — a stored mark is idempotent, so a failed find after
  /// it repeats safely.
  Future<void> retry() {
    final last = _last;
    return _find(skip: last?.skip ?? const [], mark: last?.mark, spot: last?.spot);
  }

  void takeBrief(NextScene scene) {
    _brief = (documentId: scene.documentId, headline: scene.headline, prompt: scene.prompt);
    notifyListeners();
  }

  void closeBrief() {
    _brief = null;
    notifyListeners();
  }

  Future<void> _find({required List<String> skip, SpotMark? mark, String? spot}) async {
    final seq = ++_seq;
    _last = (skip: skip, mark: mark, spot: spot);
    _pending = true;
    _error = null;
    _scene = null;
    notifyListeners();
    try {
      if (mark != null && spot != null) await markNextSceneSpot(projectId, spot, mark);
      final scene = await findNextScene(projectId, skip: skip);
      if (seq != _seq || _disposed) return;
      _scene = scene;
    } catch (e) {
      if (seq != _seq || _disposed) return;
      if (kDebugMode) debugPrint('[NextSceneFinder] find failed: $e');
      _error = e;
    }
    _pending = false;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
