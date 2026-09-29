import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mara/providers.dart';
import '../poltergeist/ids.dart';
import '../server/chat/api.dart';
import '../server/dto/chat.dart';
import '../server/dto/chat_conversation.dart';
import '../server/dto/realtime.dart';
import '../server/errors.dart';
import '../server/jobs/api.dart';
import '../server/providers.dart';
import '../server/ws.dart';
import 'live_answer.dart';
import 'providers.dart';

// The conversation owner — all the chat logic the phone carries. The server
// keeps the conversation (2026-09-29): a message is a row, an answer is a row
// written by a job that runs whether or not this app is watching. So this
// notifier posts the author's messages and draws the conversation as the
// server has it — read whole on opening, on every reconnect, on resume, and
// whenever the live frames leave a doubt; followed in between over /ws.
//
// No transcript is ever written from here, and no session is created after
// the fact: a first message with no session makes one, and the server names
// it after the first answer.
//
// Streaming: the running answer is a [LiveAnswer] of two ValueNotifiers that
// the frames feed in place. This notifier's own state changes when a message
// is added or its status moves, never per frame.

sealed class SendOutcome {
  const SendOutcome();
}

/// The server has the message.
class SendDone extends SendOutcome {
  const SendDone();
}

/// It did not get there (the network, usually). The words stay in the
/// composer; sending them again reuses the message's id, so a send that did
/// land after all is not recorded twice.
class SendFailed extends SendOutcome {
  const SendFailed();
}

/// The server refused before recording anything — a spent counter or the
/// plan. The words are still in the composer.
class SendRefused extends SendOutcome {
  const SendRefused(this.error);
  final ServerError error;
}

/// An answer another model gave, because the picked one ([from]) can't see a
/// picture it looked at.
typedef ModelSwitch = ({String model, String from});

class ConversationState {
  const ConversationState({
    this.sessionId,
    this.messages = const [],
    this.status = ConversationStatus.idle,
    this.live,
    this.posting = false,
    this.stopping = false,
    this.loading = false,
    this.error,
    this.view,
    this.workPlanId,
  });

  /// Null for a conversation nothing has been said in yet.
  final String? sessionId;
  final List<ChatMessage> messages;

  /// Whether the server is answering (or has a message waiting).
  final ConversationStatus status;

  /// The answer being written, fed by the frames. Present whenever the
  /// conversation is answering — without an id while the answer's row does
  /// not exist yet.
  final LiveAnswer? live;

  /// A message on its way to the server.
  final bool posting;

  /// Stop was asked for; the answer ends at its next tool step.
  final bool stopping;

  /// A conversation just opened, not read yet.
  final bool loading;
  final String? error;

  /// What this conversation's tools last opened — the session row's `view`,
  /// and what the Review button shows.
  final ChatView? view;

  /// The work plan this conversation works under: the session row's, or the
  /// one the author started a fresh chat from (the first message carries it).
  final String? workPlanId;

  /// No messages while the conversation answers (Cleo, 2026-09-29): the
  /// composer offers Stop instead.
  bool get answering => status != ConversationStatus.idle;

  /// Sending, or answering: what the composer and the review pages wait on.
  bool get busy => posting || answering;

  /// The running answer's job — what Stop cancels.
  String? get runningJobId => messages.where((m) => m.isRunningAnswer).lastOrNull?.jobId;

  ConversationState copyWith({
    String? sessionId,
    List<ChatMessage>? messages,
    ConversationStatus? status,
    LiveAnswer? live,
    bool clearLive = false,
    bool? posting,
    bool? stopping,
    bool? loading,
    String? error,
    bool clearError = false,
    ChatView? view,
    bool clearView = false,
    String? workPlanId,
    bool clearWorkPlan = false,
  }) =>
      ConversationState(
        sessionId: sessionId ?? this.sessionId,
        messages: messages ?? this.messages,
        status: status ?? this.status,
        live: clearLive ? null : (live ?? this.live),
        posting: posting ?? this.posting,
        stopping: stopping ?? this.stopping,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        view: clearView ? null : (view ?? this.view),
        workPlanId: clearWorkPlan ? null : (workPlanId ?? this.workPlanId),
      );
}

bool _isRefusal(Object e) =>
    e is ServerError && (e.code == 'quota_exceeded' || e.code == 'plan_insufficient');

/// The three calls the conversation makes, as a seam a test can replace.
class ConversationApi {
  const ConversationApi();

  Future<ChatSendResult> send(
    String projectId, {
    required String id,
    String? sessionId,
    required String text,
    required List<ChatAttachment> attachments,
    String? model,
    required String manuscript,
    ChatView? view,
    String? workPlanId,
  }) =>
      sendMessage(
        projectId,
        id: id,
        sessionId: sessionId,
        text: text,
        attachments: attachments,
        model: model,
        manuscript: manuscript,
        view: view,
        workPlanId: workPlanId,
      );

  Future<ChatConversation> read(String projectId, String sessionId) => readConversation(projectId, sessionId);

  /// Cancel the running answer's job. It ends `stopped` with what it had.
  Future<void> stop(String projectId, String jobId) => dismissJob(projectId, jobId);
}

final conversationApiProvider = Provider<ConversationApi>((ref) => const ConversationApi());

class ConversationNotifier extends Notifier<ConversationState> with WidgetsBindingObserver {
  ConversationNotifier(this.projectId);
  final String projectId;

  /// The server beats every 10 s while an answer runs. Three missed and the
  /// socket is not to be trusted: read the conversation instead.
  static const beatSilence = Duration(seconds: 30);

  /// Past the server's row flush (every 1.5 s): a read after this has the
  /// words a hole was missing, if any read will.
  static const _flushWait = Duration(seconds: 2);

  /// Frames kept per answer — hours of prose; past it a read is the source.
  static const _heardCap = 5000;

  bool _alive = false;
  late ConversationApi _api;
  late RealtimeFeed _feed;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Timer? _silence;
  Timer? _soon;

  /// Every frame heard per answer while it runs, to lay over the row after
  /// each read (see live_answer.dart). Dropped when the answer ends.
  final Map<String, List<ChatStreamFrame>> _heard = {};

  /// Bumped by every switch of conversation; a send that returns into a
  /// different one leaves the screen alone.
  int _token = 0;
  Future<void>? _reading;
  bool _readAgain = false;

  /// The send that failed on the network, so sending the same words again
  /// sends the same message.
  ({String id, String key})? _unsent;

  @override
  ConversationState build() {
    _alive = true;
    _api = ref.watch(conversationApiProvider);
    _feed = ref.watch(realtimeProvider);
    WidgetsBinding.instance.addObserver(this);
    _subscriptions
      ..add(_feed.project(projectId).listen(_onEvent))
      ..add(_feed.resyncs.listen((_) => _reread()));
    ref.onDispose(() {
      _alive = false;
      WidgetsBinding.instance.removeObserver(this);
      for (final s in _subscriptions) {
        unawaited(s.cancel());
      }
      _subscriptions.clear();
      _silence?.cancel();
      _soon?.cancel();
    });
    return const ConversationState();
  }

  Future<SendOutcome> send(
    String text,
    List<ChatAttachment> attachments,
    String? model, {
    required String manuscript,
  }) async {
    if (state.busy) return const SendFailed();
    final key = '$text\u0000${attachments.map((a) => a.id).join(',')}';
    final id = _unsent?.key == key ? _unsent!.id : newId();
    final sessionId = state.sessionId;
    final token = _token;
    state = state.copyWith(posting: true, clearError: true);
    try {
      final sent = await _api.send(
        projectId,
        id: id,
        sessionId: sessionId,
        text: text,
        attachments: attachments,
        model: model,
        manuscript: manuscript,
        view: state.view,
        workPlanId: state.workPlanId,
      );
      _unsent = null;
      if (!_alive) return const SendDone();
      _invalidateSessions();
      if (token != _token) return const SendDone();
      final session = sent.session;
      state = state.copyWith(
        sessionId: session?.id ?? sent.message.sessionId,
        messages: _upsert(state.messages, sent.message),
        status: sent.status == ChatSendStatus.queued ? ConversationStatus.queued : ConversationStatus.running,
        live: state.live ?? LiveAnswer(),
        posting: false,
        view: session?.view,
        workPlanId: session?.workPlanId,
      );
      _armSilence();
      unawaited(_reread());
      return const SendDone();
    } catch (e) {
      if (!_alive) return const SendFailed();
      if (token == _token) state = state.copyWith(posting: false);
      if (_isRefusal(e)) {
        // Explained by a notice, not an error bar. Nothing was recorded, so
        // the next try is a new message.
        _unsent = null;
        return SendRefused(e as ServerError);
      }
      final taken = e is ServerError && e.code == 'message_id_taken';
      _unsent = taken ? null : (id: id, key: key);
      if (token == _token) state = state.copyWith(error: messageFor(e));
      return const SendFailed();
    } finally {
      // Charged on acceptance; a refusal may have been refunded. A count
      // stuck low is the same wrong as one stuck high.
      if (_alive) ref.invalidate(quotaProvider);
    }
  }

  /// Stop the running answer. It lands at the answer's next tool step, and
  /// the answer keeps what it had written.
  Future<void> stop() async {
    if (state.stopping) return;
    var jobId = state.runningJobId;
    if (jobId == null) {
      await _reread();
      jobId = state.runningJobId;
    }
    if (jobId == null || !_alive) return;
    state = state.copyWith(stopping: true);
    try {
      await _api.stop(projectId, jobId);
    } catch (e) {
      if (_alive) state = state.copyWith(stopping: false, error: messageFor(e));
    }
  }

  Future<void> selectSession(String id) async {
    if (id == state.sessionId) return;
    _switch();
    state = ConversationState(sessionId: id, loading: true);
    await _reread();
  }

  /// A fresh conversation — under [plan] when the author started it from
  /// one: the plan is open beside it from the first message, and the
  /// conversation that message starts is filed under it.
  void newChat({({String id, String name})? plan}) {
    _switch();
    state = plan == null
        ? const ConversationState()
        : ConversationState(
            view: ChatView(kind: ChatViewKind.workPlan, id: plan.id, title: plan.name),
            workPlanId: plan.id,
          );
  }

  /// A plan was deleted: this conversation is no longer under it, and a
  /// fresh one must not name it in its first message (the server would 404).
  void forgetPlan(String planId) {
    final view = state.view;
    final showing = view?.kind == ChatViewKind.workPlan && view?.id == planId;
    if (state.workPlanId != planId && !showing) return;
    state = state.copyWith(clearWorkPlan: state.workPlanId == planId, clearView: showing);
  }

  void clearError() => state = state.copyWith(clearError: true);

  void _switch() {
    _token++;
    _unsent = null;
    _silence?.cancel();
    _soon?.cancel();
    _soon = null;
    _heard.clear();
  }

  // Back from the background: the socket may have died unseen, and frames
  // sent meanwhile are gone. Read the conversation as it stands.
  @override
  // ignore: avoid_renaming_method_parameters — `state` here would shadow the notifier's own.
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle != AppLifecycleState.resumed) return;
    _feed.wake();
    unawaited(_reread());
  }

  void _onEvent(ProjectChangeEvent event) {
    switch (event.entity) {
      case 'chat_session':
        _invalidateSessions();
      case 'chat_message':
        // The drawer's running dot and, after a first answer, the title.
        _invalidateSessions();
        if (ChatMessageEvent.fromJson(event.raw).sessionId == state.sessionId) unawaited(_reread());
      case 'chat_stream':
        final frame = ChatStreamFrame.fromJson(event.raw);
        if (frame.sessionId == state.sessionId) _onFrame(frame);
      case 'job':
        // A task's status is its job's; the message row never moves for it.
        final task = state.messages.where((m) => m.role == ChatRole.task && m.jobId == event.id).firstOrNull;
        if (task != null && event.jobStatus?.name != task.status.name) unawaited(_reread());
    }
  }

  void _onFrame(ChatStreamFrame frame) {
    _armSilence();
    final heard = _heard.putIfAbsent(frame.id, () => []);
    if (heard.length < _heardCap) heard.add(frame);
    if (frame is StreamView && frame.view != null) state = state.copyWith(view: frame.view);
    final live = state.live;
    // An answer this app has not read yet — its row is newer than the last
    // read. The frames wait in [_heard] for the read that binds it.
    if (live == null || live.id != frame.id) {
      unawaited(_reread());
      return;
    }
    _follow(live.apply(frame));
  }

  void _follow(FrameVerdict verdict) {
    switch (verdict) {
      case FrameVerdict.applied:
        break;
      case FrameVerdict.reread:
        unawaited(_reread());
      case FrameVerdict.rereadSoon:
        _soon ??= Timer(_flushWait, () {
          _soon = null;
          unawaited(_reread());
        });
    }
  }

  /// While the conversation answers, a frame (the beat at least) is due
  /// every 10 s; this fires when none came.
  void _armSilence() {
    _silence?.cancel();
    if (!state.busy) return;
    _silence = Timer(beatSilence, () {
      if (!_alive) return;
      unawaited(_reread());
      _armSilence();
    });
  }

  /// Read the open conversation. Calls made while a read is out fold into
  /// one more read after it, so a burst of events costs two reads, not ten.
  Future<void> _reread() {
    if (!_alive || state.sessionId == null) return Future.value();
    final reading = _reading;
    if (reading != null) {
      _readAgain = true;
      return reading;
    }
    return _reading = _readLoop().whenComplete(() => _reading = null);
  }

  Future<void> _readLoop() async {
    do {
      _readAgain = false;
      final sessionId = state.sessionId;
      if (sessionId == null) return;
      try {
        final conversation = await _api.read(projectId, sessionId);
        if (!_alive) return;
        // Opened another conversation meanwhile: read that one instead.
        if (sessionId != state.sessionId) {
          _readAgain = true;
          continue;
        }
        _apply(conversation);
      } catch (e) {
        if (kDebugMode) debugPrint('[conversation] read failed: $e');
        if (_alive && sessionId == state.sessionId && state.loading) {
          state = state.copyWith(loading: false, error: messageFor(e));
        }
      }
    } while (_readAgain && _alive);
  }

  void _apply(ChatConversation conversation) {
    final before = {for (final m in state.messages) m.id: m.status};
    final messages = conversation.messages;
    final running = messages.where((m) => m.isRunningAnswer).lastOrNull;
    final held = state.live;
    final LiveAnswer? live;
    if (running != null) {
      live = held != null && held.id == running.id ? held : LiveAnswer(id: running.id);
      _follow(live.settle(running, _heard[running.id] ?? const []));
    } else if (conversation.status != ConversationStatus.idle) {
      // Answering, but the answer's row is not there yet.
      live = held != null && held.id == null ? held : LiveAnswer();
    } else {
      live = null;
    }
    _heard.removeWhere((id, _) => id != running?.id);
    final session = conversation.session;
    state = ConversationState(
      sessionId: state.sessionId,
      messages: messages,
      status: conversation.status,
      live: live,
      posting: state.posting,
      stopping: state.stopping && conversation.status != ConversationStatus.idle,
      error: state.error,
      view: session.view,
      workPlanId: session.workPlanId,
    );
    _armSilence();
    _landed(before, messages);
  }

  /// What a message finishing makes stale elsewhere in the app.
  void _landed(Map<String, ChatMessageStatus> before, List<ChatMessage> messages) {
    for (final m in messages) {
      if (before[m.id] != ChatMessageStatus.running || m.status == ChatMessageStatus.running) continue;
      switch (m.role) {
        case ChatRole.task:
          ref.invalidate(authoredOutlineProvider(projectId));
        case ChatRole.assistant:
          ref.invalidate(quotaProvider);
          if (m.result?.workPlanId != null) ref.invalidate(workPlansProvider(projectId));
        case ChatRole.user || ChatRole.unknown:
          break;
      }
    }
  }

  void _invalidateSessions() {
    if (_alive) ref.invalidate(chatSessionsProvider(projectId));
  }
}

List<ChatMessage> _upsert(List<ChatMessage> messages, ChatMessage message) {
  final at = messages.indexWhere((m) => m.id == message.id);
  if (at != -1) return [for (var i = 0; i < messages.length; i++) i == at ? message : messages[i]];
  return [...messages, message]..sort((a, b) => a.seq.compareTo(b.seq));
}
