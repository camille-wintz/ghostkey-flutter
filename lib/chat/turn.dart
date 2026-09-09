import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/chat/api.dart';
import '../server/dto/chat.dart';
import '../server/errors.dart';
import '../server/providers.dart';
import 'providers.dart';
import 'session_title.dart';

// The turn owner — all the chat logic the phone carries. No prompts, no
// tools, no model protocol: the server runs the loop (POST /chat/turn) and
// this notifier sends the transcript, draws what streams back, and keeps the
// session row in step. Mirrors the RN app's useChatTurn, which mirrors the
// desktop's chat.tsx `runSend` + useChatSessions.persistTurn.
//
// Persistence: the first completed turn of a fresh conversation creates the
// session (placeholder title, upgraded a moment later by the title call);
// every later turn is written by the SERVER as it completes, because the send
// names the session — which is what lets a turn survive a locked phone.
//
// Streaming: the in-flight turn is a [PendingTurn] of two ValueNotifiers, so
// a token appends to a value the last bubble alone listens to. The notifier's
// own state changes once at the start of a turn and once at its end; nothing
// rebuilds the thread per frame.

/// The in-flight assistant turn. Mutable on purpose — see the file note.
class PendingTurn {
  final ValueNotifier<List<ChatToolStep>> steps = ValueNotifier(const []);

  /// Answer prose so far. Cleared by a step frame: text before a tool call
  /// was narration, not the answer.
  final ValueNotifier<String> text = ValueNotifier('');
}

sealed class SendOutcome {
  const SendOutcome();
}

class SendDone extends SendOutcome {
  const SendDone();
}

class SendStopped extends SendOutcome {
  const SendStopped();
}

class SendFailed extends SendOutcome {
  const SendFailed();
}

/// The server refused before spending. The message goes back to the composer.
class SendRefused extends SendOutcome {
  const SendRefused(this.error, this.text, this.attachments);
  final ServerError error;
  final String text;
  final List<ChatAttachment> attachments;
}

class ChatTurnState {
  const ChatTurnState({
    this.messages = const [],
    this.activeSessionId,
    this.pending,
    this.sending = false,
    this.error,
    this.stepsByIndex = const {},
    this.notesByIndex = const {},
  });

  final List<ChatMessage> messages;
  final String? activeSessionId;
  final PendingTurn? pending;
  final bool sending;
  final String? error;

  /// Recall steps and save_note receipts by assistant message index. Live
  /// transcript only — a reloaded session shows answers without them.
  final Map<int, List<ChatToolStep>> stepsByIndex;
  final Map<int, List<ChatSavedNote>> notesByIndex;

  ChatTurnState copyWith({
    List<ChatMessage>? messages,
    String? activeSessionId,
    bool clearSession = false,
    PendingTurn? pending,
    bool clearPending = false,
    bool? sending,
    String? error,
    bool clearError = false,
    Map<int, List<ChatToolStep>>? stepsByIndex,
    Map<int, List<ChatSavedNote>>? notesByIndex,
  }) =>
      ChatTurnState(
        messages: messages ?? this.messages,
        activeSessionId: clearSession ? null : (activeSessionId ?? this.activeSessionId),
        pending: clearPending ? null : (pending ?? this.pending),
        sending: sending ?? this.sending,
        error: clearError ? null : (error ?? this.error),
        stepsByIndex: stepsByIndex ?? this.stepsByIndex,
        notesByIndex: notesByIndex ?? this.notesByIndex,
      );
}

/// A step arrives twice — `running`, then `done` / `error` — keyed by tool +
/// summary.
List<ChatToolStep> upsertStep(List<ChatToolStep> steps, ChatToolStep step) {
  final at = steps.indexWhere((s) => s.tool == step.tool && s.summary == step.summary);
  if (at == -1) return [...steps, step];
  return [for (var i = 0; i < steps.length; i++) i == at ? step : steps[i]];
}

bool _isRefusal(Object e) =>
    e is ServerError && (e.code == 'quota_exceeded' || e.code == 'plan_insufficient');

class ChatTurnNotifier extends Notifier<ChatTurnState> with WidgetsBindingObserver {
  ChatTurnNotifier(this.projectId);
  final String projectId;

  bool _alive = false;

  /// Bumped by every session switch; a turn whose token no longer matches
  /// has been superseded and touches no state.
  int _token = 0;
  TurnHandle? _handle;
  Completer<void>? _stop;

  /// The first turn's session create in flight, so a fast second send waits
  /// for the id instead of creating a second session.
  Future<void> _persist = Future.value();

  /// A stopped turn's session: the server is still finishing it, and the
  /// next foreground read picks the answer up.
  String? _awaiting;

  @override
  ChatTurnState build() {
    _alive = true;
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _alive = false;
      WidgetsBinding.instance.removeObserver(this);
      unawaited(_handle?.cancel());
    });
    return const ChatTurnState();
  }

  Future<SendOutcome> send(String text, List<ChatAttachment> attachments, String model) async {
    if (state.sending) return const SendFailed();
    await _persist.catchError((_) {});
    if (!_alive) return const SendFailed();

    final before = state.messages;
    final transcript = [...before, ChatMessage(role: ChatRole.user, text: text, attachments: attachments)];
    final assistantIndex = transcript.length;
    final sessionId = state.activeSessionId;
    final token = _token;
    final stop = Completer<void>();
    _stop = stop;
    final pending = PendingTurn();

    state = state.copyWith(clearError: true, messages: transcript, pending: pending, sending: true);

    try {
      final handle = await streamTurn(
        projectId,
        messages: transcript,
        model: model,
        sessionId: sessionId,
        onStep: (step) {
          pending.steps.value = upsertStep(pending.steps.value, step);
          pending.text.value = '';
        },
        onText: (chunk) => pending.text.value = pending.text.value + chunk,
      );
      // Stopped while the request was still opening: nothing to read.
      if (stop.isCompleted) {
        await handle.cancel();
        return const SendStopped();
      }
      _handle = handle;
      // A cancelled subscription never completes `result`, so the stop has
      // to win the race by itself.
      final result = await Future.any<ChatTurnResult?>([
        handle.result,
        stop.future.then((_) => null),
      ]);
      if (result == null) return const SendStopped();

      final finalMessages = [...transcript, ChatMessage(role: ChatRole.assistant, text: result.answer)];
      if (token == _token && _alive) {
        state = state.copyWith(
          messages: finalMessages,
          stepsByIndex: {...state.stepsByIndex, assistantIndex: result.steps},
          notesByIndex: result.savedNotes.isEmpty
              ? null
              : {...state.notesByIndex, assistantIndex: result.savedNotes},
        );
      }
      _persist = _persistTurn(finalMessages, result.session, sessionId, token);
      return const SendDone();
    } catch (e) {
      if (stop.isCompleted) return const SendStopped();
      if (token != _token || !_alive) return const SendFailed();
      if (_isRefusal(e)) {
        // Explained by a notice, not an error bar — and the question goes
        // back to the composer rather than sitting unanswered for no reason.
        state = state.copyWith(messages: before);
        return SendRefused(e as ServerError, text, attachments);
      }
      state = state.copyWith(error: messageFor(e));
      return const SendFailed();
    } finally {
      if (_alive && token == _token) state = state.copyWith(clearPending: true, sending: false);
      if (_stop == stop) _stop = null;
      _handle = null;
      // Fired on failure too: a refused send may have had its charge
      // refunded, and a count stuck low is the same wrong as one stuck high.
      if (_alive) ref.invalidate(quotaProvider);
    }
  }

  /// Replace the placeholder with the model's title — only if the row still
  /// carries the placeholder, so a rename made meanwhile wins. Best-effort:
  /// the model may decline and the plan may refuse the call.
  Future<void> _nameSession(String sessionId, String placeholder, List<ChatMessage> turns) async {
    try {
      final suggested = await suggestTitle(projectId, turns);
      if (suggested.isEmpty) return;
      final current = await getSession(projectId, sessionId);
      if (current.title != placeholder) return;
      await patchSession(projectId, sessionId, title: suggested);
      _invalidateSessions();
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatTurn] title failed: $e');
    }
  }

  Future<void> _persistTurn(
    List<ChatMessage> finalMessages,
    ChatSession? written,
    String? sessionId,
    int token,
  ) async {
    try {
      if (sessionId == null) {
        final firstUser = finalMessages.where((m) => m.role == ChatRole.user).firstOrNull;
        final placeholder = placeholderTitle(firstUser);
        final created = await createSession(projectId, title: placeholder, messages: finalMessages);
        if (token == _token && _alive) state = state.copyWith(activeSessionId: created.id);
        _invalidateSessions();
        // After the transcript is safe, never before: naming is a model
        // call, and nothing the author typed may wait on one.
        await _nameSession(created.id, placeholder, finalMessages);
        return;
      }
      // The server wrote transcript + answer when the turn completed; null
      // means the write did not land (a transcript past the cap, usually),
      // and the PATCH says why with a status instead of nothing.
      if (written == null) await patchSession(projectId, sessionId, messages: finalMessages);
      _invalidateSessions();
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatTurn] persist failed: $e');
    }
  }

  void _invalidateSessions() {
    if (_alive) ref.invalidate(chatSessionsProvider(projectId));
  }

  Future<void> selectSession(String id) async {
    if (id == state.activeSessionId) return;
    _abort();
    final token = ++_token;
    try {
      final session = await getSession(projectId, id);
      if (token != _token || !_alive) return;
      state = ChatTurnState(activeSessionId: id, messages: session.messages);
      _awaiting = null;
    } catch (e) {
      if (_alive) state = state.copyWith(error: messageFor(e));
    }
  }

  void newChat() {
    _abort();
    _token++;
    _awaiting = null;
    state = const ChatTurnState();
  }

  /// Abort the stream. The server still finishes and persists the turn.
  void stop() {
    _awaiting = state.activeSessionId;
    _abort();
  }

  void clearError() => state = state.copyWith(clearError: true);

  void _abort() {
    unawaited(_handle?.cancel());
    _handle = null;
    final stop = _stop;
    if (stop != null && !stop.isCompleted) stop.complete();
  }

  // The SSE that died in the background is not resumed. Because the server
  // appends the assistant turn itself, coming back only means asking the
  // session whether the answer is there.
  @override
  // ignore: avoid_renaming_method_parameters — `state` here would shadow the notifier's own.
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) _resync();
  }

  void _resync() {
    final sessionId = state.activeSessionId;
    if (sessionId == null) return;
    if (!state.sending && _awaiting != sessionId) return;
    final token = _token;
    getSession(projectId, sessionId).then((session) {
      if (!_alive || token != _token || state.activeSessionId != sessionId) return;
      final last = session.messages.lastOrNull;
      if (session.messages.length <= state.messages.length || last?.role != ChatRole.assistant) return;
      // The answer landed. The dead stream's late result, if it ever
      // arrives, has nothing left to add.
      _abort();
      _token++;
      _awaiting = null;
      state = state.copyWith(messages: session.messages, clearPending: true, sending: false);
      _invalidateSessions();
    }).catchError((_) {});
  }
}
