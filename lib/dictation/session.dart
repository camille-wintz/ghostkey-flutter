import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../server/dto/transcribe.dart';
import '../server/errors.dart';
import 'background_mode.dart';
import 'notices.dart';
import 'policy.dart';
import 'recorder_channel.dart';
import 'seam_ledger.dart';
import 'transcribe.dart';

// One dictation session: the native recorder driven by the chunk policy,
// each finished chunk shipped to the server, the transcripts landed in the
// order they were spoken. Ported from ghostkey-mobile
// `src/audio/useChunkedRecorder.ts`, minus everything that existed only
// because that recorder stops and re-arms at every chunk (the interruption
// re-arm, the "recorder never reported metering" fallbacks, the
// expecting-finish handshake): here the mic runs once for the whole session
// and a chunk is a cut of its encoded stream (see policy.dart, and
// android/…/recorder/README.md).
//
// The dock reads this as a ChangeNotifier; the flow owns its lifetime.

class DictationSession extends ChangeNotifier with WidgetsBindingObserver {
  DictationSession({
    required this.projectId,
    required this.onTranscript,
    required this.previousText,
    this.onRefused,
  });

  final String projectId;

  /// A transcript, ready to land. Called in spoken order.
  final void Function(String text) onTranscript;

  /// The manuscript immediately before the insertion point, read fresh at the
  /// moment a chunk ships, so the cleanup pass can tell whether a quotation
  /// is already open.
  final String Function() previousText;

  /// A plan refusal will refuse every chunk: the flow closes the dock rather
  /// than let it keep recording what can never land.
  final void Function(ServerError error)? onRefused;

  final NativeRecorder _native = NativeRecorder();
  final SessionPolicy _policy = SessionPolicy();
  final SeamLedger _ledger = SeamLedger();
  StreamSubscription<RecorderEvent>? _events;

  /// A native session is live (started, not yet stopped).
  bool _live = false;
  bool _paused = false;
  bool _cutting = false;
  bool _starting = false;
  BackgroundMode _mode = BackgroundMode.background;
  int _sessions = 0;
  int _lastElapsedMs = 0;
  int _durationBase = 0;

  // The session so far, in spoken order — appended as each chunk's transcript
  // LANDS (inside the ordered delivery chain), not as it is dispatched, so a
  // slow chunk never files its turn ahead of a faster one spoken later.
  final List<TranscriptTurn> _turns = [];

  // Chunks upload in parallel — a slow one must not stall the next — but
  // their transcripts land in the order they were spoken: each chunk's
  // insertion is chained behind the previous chunk's.
  Future<void> _delivery = Future<void>.value();

  // A cut/pause/stop resolves with the path of the file being finished; its
  // `chunk` event follows on the capture thread's own time. Waiters by path,
  // and events that beat their waiter.
  final Map<String, Completer<RecorderChunk?>> _waiters = {};
  final Map<String, RecorderChunk> _early = {};

  // ── What the dock draws ───────────────────────────────────────────────────

  bool get isRecording => _live && !_paused;
  bool get isPaused => !isRecording;
  bool get isProcessing => _policy.pending > 0;
  List<double> levels = List<double>.filled(DictationPolicy.waveBars, 0);
  int durationMs = 0;
  DockNotice? notice;
  bool _disposed = false;

  /// Resolves when every chunk in flight has landed or been given up. The
  /// flow disposes the session after this, not at Done.
  Future<void> get drained => _delivery;

  // ── Start / pause / resume / stop ─────────────────────────────────────────

  /// Begin (or, after an auto-stop, begin again). No-op while live.
  Future<void> start() async {
    if (_live || _starting || _disposed) return;
    _starting = true;
    try {
      final perms = await _native.permissions();
      if (!perms.microphone && !await _native.requestMicrophone()) {
        _setNotice(microphoneDeniedNotice);
        return;
      }
      final chosen = await chooseBackgroundMode(_native);
      _mode = chosen.mode;
      if (chosen.reason != null) _setNotice(foregroundOnlyNotice(chosen.reason!));

      _events ??= _native.events.listen(_onEvent);
      _sessions += 1;
      final sessionId = '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-$_sessions';
      final started = _native.events
          .firstWhere((e) => e is RecorderStarted || e is RecorderError)
          .timeout(const Duration(seconds: 6));
      await _native.start(RecorderOptions(sessionId: sessionId));
      final event = await started;
      if (event is RecorderError) {
        _setNotice(recorderFailedNotice(event.message));
        return;
      }
      final startedEvent = event as RecorderStarted;
      if (!startedEvent.backgroundCapable && _mode == BackgroundMode.background) {
        _mode = BackgroundMode.foreground;
        _setNotice(foregroundOnlyNotice(ForegroundOnlyReason.noService));
      }
      _live = true;
      _paused = false;
      _lastElapsedMs = 0;
      _durationBase = durationMs;
      _policy.startSession(_now);
      WidgetsBinding.instance.addObserver(this);
      notifyListeners();
    } on RecorderStartException catch (e) {
      _setNotice(e.code == 'microphone_denied' ? microphoneDeniedNotice : recorderFailedNotice(e.message));
    } on TimeoutException {
      _setNotice(recorderFailedNotice('It did not start in time.'));
    } finally {
      _starting = false;
    }
  }

  /// Pause: the running chunk is cut and shipped; the mic stays open so
  /// resuming has no seam. A paused session is not clocked — idle and the
  /// ceiling restart on resume, as the RN app's play-after-pause did.
  Future<void> pause() async {
    if (!_live || _paused) return;
    _paused = true;
    notifyListeners();
    final voiced = _policy.chunkVoiced;
    final chunk = await _finishChunk(_native.pause);
    _handleFinished(chunk, voiced);
  }

  /// Play: resume the paused native session, or start a new one after an
  /// auto-stop. The insertion point and the session turns carry over.
  Future<void> resume() async {
    notice = null;
    if (_live && _paused) {
      await _native.resume();
      _paused = false;
      _policy.startSession(_now);
      notifyListeners();
      return;
    }
    await start();
  }

  /// Done. Chunks still in flight keep landing after this resolves.
  Future<void> stop() async {
    if (!_live) return;
    await _end(null);
  }

  // ── Events from the recorder ──────────────────────────────────────────────

  void _onEvent(RecorderEvent e) {
    switch (e) {
      case RecorderLevel():
        _onLevel(e);
      case RecorderChunk():
        _onChunk(e);
      case RecorderStopped():
        _onStopped(e);
      case RecorderError():
        if (_live) _setNotice(recorderFailedNotice(e.message));
      case RecorderStarted():
        break;
    }
  }

  void _onLevel(RecorderLevel e) {
    final sampleMs = (e.elapsedMs - _lastElapsedMs).clamp(0, 1000);
    _lastElapsedMs = e.elapsedMs;
    durationMs = _durationBase + e.elapsedMs;
    levels = [...levels.skip(1), DictationPolicy.normalizeDb(e.db)];
    notifyListeners();
    if (!_live || _paused || _cutting) return;
    switch (_policy.onLevel(db: e.db, nowMs: _now, sampleMs: sampleMs)) {
      case KeepGoing():
        break;
      case CutChunk():
        unawaited(_cut());
      case EndSession(:final reason):
        unawaited(_end(reason));
    }
  }

  Future<void> _cut() async {
    if (_cutting) return;
    _cutting = true;
    try {
      final voiced = _policy.chunkVoiced;
      final chunk = await _finishChunk(_native.cut);
      _handleFinished(chunk, voiced);
      _policy.startChunk(_now);
    } finally {
      _cutting = false;
    }
  }

  void _onChunk(RecorderChunk e) {
    _ledger.add(index: e.index, startFrame: e.startFrame, endFrame: e.endFrame);
    final waiter = _waiters.remove(e.path);
    if (waiter != null) {
      waiter.complete(e);
      return;
    }
    if (_cutting || _paused) {
      // The event beat the method result; the waiter picks it up.
      _early[e.path] = e;
      return;
    }
    // Finished by the native side (the notification's Stop, a task removal):
    // judged by its own count, since this side's may not have seen its last
    // levels.
    _handleFinished(e, e.heardSpeech || _policy.chunkVoiced);
  }

  void _onStopped(RecorderStopped e) {
    // Anyone still waiting for a file is not getting one.
    for (final w in _waiters.values) {
      if (!w.isCompleted) w.complete(null);
    }
    _waiters.clear();
    if (kDebugMode) {
      final report = _ledger.report(samplesIn: e.samplesIn, framesOut: e.framesOut);
      debugPrint('[dictation] ${report ?? 'seam clean: ${_ledger.chunkCount} chunk(s), ${e.framesOut} frames'}');
    }
    if (e.reason == NativeStopReason.client) return;
    // The native side ended the session on its own.
    if (!_live) return;
    _live = false;
    _paused = false;
    WidgetsBinding.instance.removeObserver(this);
    switch (e.reason) {
      case NativeStopReason.notification:
        _setNotice(autoStopNotice(AutoStopReason.stopped));
      case NativeStopReason.error:
        _setNotice(recorderFailedNotice('Something went wrong with the microphone.'));
      case NativeStopReason.taskRemoved:
      case NativeStopReason.restarted:
      case NativeStopReason.destroyed:
      case NativeStopReason.client:
        notifyListeners();
    }
  }

  /// Ask the native side to finish the running chunk and wait for its event.
  Future<RecorderChunk?> _finishChunk(Future<String?> Function() op) async {
    final path = await op();
    if (path == null) return null;
    final early = _early.remove(path);
    if (early != null) return early;
    final completer = _waiters.putIfAbsent(path, Completer<RecorderChunk?>.new);
    try {
      return await completer.future.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      _waiters.remove(path);
      debugPrint('[dictation] chunk did not finalise: $path');
      return null;
    }
  }

  /// A finished file: ship it if it held speech, otherwise delete it without
  /// a round trip or the charge.
  void _handleFinished(RecorderChunk? chunk, bool voiced) {
    if (chunk == null) return;
    if (voiced) {
      _policy.noteActivity(_now);
      _dispatch(chunk.path);
    } else {
      unawaited(_delete(chunk.path));
    }
  }

  Future<void> _end(AutoStopReason? reason) async {
    if (!_live) return;
    _live = false;
    _paused = false;
    WidgetsBinding.instance.removeObserver(this);
    if (reason != null) {
      debugPrint('[dictation] session auto-stopped (${reason.name})');
      _setNotice(autoStopNotice(reason));
    } else {
      notifyListeners();
    }
    final voiced = _policy.chunkVoiced;
    final chunk = await _finishChunk(_native.stop);
    _handleFinished(chunk, voiced);
  }

  // A foreground-only session meeting the lock screen: without a visible
  // notification nothing should record in the background, so the session
  // ends and the dock says why. A background session is meant to outlive
  // the lock and ignores this.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused || _mode != BackgroundMode.foreground) return;
    if (_live && !_paused) unawaited(_end(AutoStopReason.locked));
  }

  // ── Upload and delivery ───────────────────────────────────────────────────

  void _dispatch(String path) {
    _policy.pending += 1;
    notifyListeners();
    final result = _transcribe(path);
    // The chain only attaches its handler when this chunk's turn comes; an
    // earlier rejection would surface as unhandled in the meantime.
    result.catchError((Object _) => const TranscriptTurn(verbatim: '', cleaned: ''));
    _delivery = _delivery.then((_) async {
      try {
        final turn = await result;
        if (turn.cleaned.isNotEmpty) {
          _policy.noteActivity(_now);
          _turns.add(turn);
          if (_turns.length > DictationPolicy.sessionTurns) _turns.removeAt(0);
          onTranscript(turn.cleaned);
        }
      } catch (e) {
        _onChunkLost(e);
      } finally {
        _policy.pending = (_policy.pending - 1).clamp(0, 1 << 30);
        if (!_disposed) notifyListeners();
      }
    });
  }

  /// Ship one chunk, retrying what may pass. The file goes either way.
  Future<TranscriptTurn> _transcribe(String path) async {
    try {
      for (var attempt = 0;; attempt++) {
        try {
          // Read per attempt, not once: a chunk that retries through a
          // network blip should carry the document as it stands now, since
          // anything that landed while it was failing sits between it and
          // its own context. The turns are read the same way: chunks upload
          // in parallel, so a chunk's history is whatever has landed by the
          // time it ships.
          final before = previousText();
          final previous =
              before.length > DictationPolicy.previousChars ? before.substring(before.length - DictationPolicy.previousChars) : before;
          final res = await transcribeAudioChunk(
            path,
            projectId: projectId,
            previous: previous,
            turns: List.of(_turns),
          );
          return TranscriptTurn(cleaned: res.text, verbatim: res.verbatim);
        } catch (e) {
          if (attempt >= DictationPolicy.retryDelaysMs.length || !_isRetryable(e)) rethrow;
          debugPrint('[dictation] transcribe failed (attempt ${attempt + 1}) — retrying: $e');
          await Future<void>.delayed(Duration(milliseconds: DictationPolicy.retryDelaysMs[attempt]));
        }
      }
    } finally {
      await _delete(path);
    }
  }

  static bool _isRetryable(Object e) {
    if (e is! ServerError) return true; // thrown below the wire — network-shaped
    return e.status >= 500 || e.code == 'network_error' || e.code == 'rate_limited';
  }

  void _onChunkLost(Object e) {
    debugPrint('[dictation] chunk lost: $e');
    if (_disposed) return;
    if (e is ServerError && e.code == 'plan_insufficient') {
      onRefused?.call(e);
      return;
    }
    _setNotice(lostChunkNotice(messageFor(e)));
  }

  Future<void> _delete(String path) async {
    try {
      await File(path).delete();
    } catch (_) {
      // Already gone, or the sweep's on the next launch.
    }
  }

  // ── Plumbing ──────────────────────────────────────────────────────────────

  int get _now => DateTime.now().millisecondsSinceEpoch;

  void _setNotice(DockNotice n) {
    notice = n;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_events?.cancel());
    _events = null;
    super.dispose();
  }
}
