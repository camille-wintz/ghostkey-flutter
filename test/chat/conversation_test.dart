import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/chat/conversation.dart';
import 'package:ghostkey/chat/live_answer.dart';
import 'package:ghostkey/chat/providers.dart';
import 'package:ghostkey/server/dto/chat.dart';
import 'package:ghostkey/server/dto/chat_conversation.dart';
import 'package:ghostkey/server/dto/realtime.dart';
import 'package:ghostkey/server/errors.dart';
import 'package:ghostkey/server/ws.dart';

const _session = 's1';
const _answer = 'a1';

ChatStreamFrame text(int n, String words, int at) =>
    StreamText(sessionId: _session, id: _answer, n: n, text: words, at: at);
ChatStreamFrame step(int n, String summary, ChatToolStepStatus status) => StreamStep(
      sessionId: _session,
      id: _answer,
      n: n,
      step: ChatToolStep(tool: 'read_chapter', summary: summary, status: status),
    );
ChatStreamFrame discard(int n) => StreamDiscard(sessionId: _session, id: _answer, n: n);
ChatStreamFrame beat(int n, int textLength) => StreamBeat(
      sessionId: _session,
      id: _answer,
      n: n,
      phase: AnswerPhase.writing,
      elapsedMs: 10000,
      steps: 0,
      textLength: textLength,
    );

ChatMessage message(
  String id,
  ChatRole role,
  ChatMessageStatus status, {
  String text = '',
  int seq = 1,
  List<ChatToolStep> steps = const [],
  String? jobId,
}) =>
    ChatMessage(id: id, sessionId: _session, seq: seq, role: role, status: status, text: text, steps: steps, jobId: jobId);

ChatMessage running(String text, {List<ChatToolStep> steps = const []}) =>
    message(_answer, ChatRole.assistant, ChatMessageStatus.running, text: text, seq: 2, steps: steps, jobId: 'job1');

/// The frames a server would send for [id] as a project change.
Map<String, dynamic> wire(ChatStreamFrame frame) => {
      'type': 'project_changes',
      'kind': 'stream',
      'entity': 'chat_stream',
      'project_id': 'p',
      'session_id': frame.sessionId,
      'id': frame.id,
      'n': frame.n,
      ...switch (frame) {
        StreamText(:final text, :final at) => {'text': text, 'at': at},
        StreamDiscard() => {'discard': true},
        StreamStep(:final step) => {
            'step': {'tool': step.tool, 'summary': step.summary, 'status': step.status.name},
          },
        StreamBeat(:final textLength) => {'phase': 'writing', 'elapsed_ms': 10000, 'steps': 0, 'text_length': textLength},
        _ => <String, dynamic>{},
      },
    };

class FakeFeed implements RealtimeFeed {
  final events = StreamController<ProjectChangeEvent>.broadcast(sync: true);
  final resyncsController = StreamController<void>.broadcast(sync: true);

  void send(Map<String, dynamic> json) => events.add(ProjectChangeEvent.fromJson(json)!);

  @override
  Stream<ProjectChangeEvent> project(String projectId) => events.stream.where((e) => e.projectId == projectId);

  @override
  Stream<void> get resyncs => resyncsController.stream;

  @override
  void wake() {}
}

class FakeApi extends ConversationApi {
  FakeApi();

  ConversationStatus status = ConversationStatus.running;
  List<ChatMessage> messages = [
    message('u1', ChatRole.user, ChatMessageStatus.answered, text: 'Hello'),
    running(''),
  ];
  int reads = 0;
  final List<String> sentIds = [];
  Object? sendError;
  final List<String> stopped = [];

  @override
  Future<ChatConversation> read(String projectId, String sessionId) async {
    reads++;
    return ChatConversation(
      session: ChatSession(id: sessionId, title: 'Hello', version: 1, updatedAt: '', projectId: projectId, createdAt: ''),
      status: status,
      messages: messages,
    );
  }

  @override
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
  }) async {
    sentIds.add(id);
    if (sendError case final e?) throw e;
    final sent = message(id, ChatRole.user, ChatMessageStatus.queued, text: text);
    return ChatSendResult(
      status: ChatSendStatus.answering,
      message: sent,
      session: ChatSession(id: _session, title: text, version: 1, updatedAt: '', projectId: projectId, createdAt: ''),
    );
  }

  @override
  Future<void> stop(String projectId, String jobId) async => stopped.add(jobId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveAnswer', () {
    test('appends words where they say they start, and takes an overlap once', () {
      final live = LiveAnswer(id: _answer);
      expect(live.apply(text(1, 'Hello', 0)), FrameVerdict.applied);
      expect(live.apply(text(2, ' there', 5)), FrameVerdict.applied);
      expect(live.text.value, 'Hello there');
      // Read mid-answer: the row already held part of what this frame carries.
      final read = LiveAnswer(id: _answer, text: 'Hello th');
      expect(read.apply(text(7, ' there, you', 5)), FrameVerdict.applied);
      expect(read.text.value, 'Hello there, you');
    });

    test('a discard clears the words and the next frame starts again', () {
      final live = LiveAnswer(id: _answer);
      live.apply(text(1, 'Draft', 0));
      live.apply(discard(2));
      expect(live.text.value, '');
      live.apply(text(3, 'Answer', 0));
      expect(live.text.value, 'Answer');
    });

    test('a step is upserted by tool and summary', () {
      final live = LiveAnswer(id: _answer);
      live.apply(step(1, 'Reading Chapter 3', ChatToolStepStatus.running));
      live.apply(step(2, 'Reading Chapter 4', ChatToolStepStatus.running));
      live.apply(step(3, 'Reading Chapter 3', ChatToolStepStatus.done));
      expect(live.steps.value.map((s) => (s.summary, s.status)), [
        ('Reading Chapter 3', ChatToolStepStatus.done),
        ('Reading Chapter 4', ChatToolStepStatus.running),
      ]);
    });

    test('a gap in n asks for a read; the first frame after a read is the baseline', () {
      final live = LiveAnswer(id: _answer);
      expect(live.apply(text(40, 'x', 0)), FrameVerdict.applied);
      expect(live.apply(text(41, 'y', 1)), FrameVerdict.applied);
      expect(live.apply(step(43, 'Reading', ChatToolStepStatus.running)), FrameVerdict.reread);
      expect(live.apply(text(41, 'y', 1)), FrameVerdict.applied, reason: 'an old frame changes nothing');
      expect(live.text.value, 'xy');
    });

    test('words starting past what is held are a hole, not something to draw around', () {
      final live = LiveAnswer(id: _answer, text: 'Hello');
      expect(live.apply(text(9, 'world', 12)), FrameVerdict.rereadSoon);
      expect(live.text.value, 'Hello');
    });

    test('a beat counting more words than are held asks for a read', () {
      final live = LiveAnswer(id: _answer, text: 'Hello');
      expect(live.apply(beat(1, 5)), FrameVerdict.applied);
      expect(live.apply(beat(2, 5000)), FrameVerdict.rereadSoon);
    });

    test('a read lays the frames heard over the row it returns', () {
      final live = LiveAnswer(id: _answer);
      final heard = [text(1, 'Hello', 0), text(2, ' there', 5), step(3, 'Reading', ChatToolStepStatus.done), text(4, ', you', 11)];
      for (final f in heard) {
        live.apply(f);
      }
      // The row was flushed after frame 2: behind the frames, and its step still running.
      final verdict = live.settle(
        running('Hello there', steps: const [ChatToolStep(tool: 'read_chapter', summary: 'Reading', status: ChatToolStepStatus.running)]),
        heard,
      );
      expect(verdict, FrameVerdict.applied);
      expect(live.text.value, 'Hello there, you');
      expect(live.steps.value.single.status, ChatToolStepStatus.done);
      // Following on from the last heard frame.
      expect(live.apply(text(5, '!', 16)), FrameVerdict.applied);
      expect(live.text.value, 'Hello there, you!');
    });
  });

  group('ConversationNotifier', () {
    late FakeApi api;
    late FakeFeed feed;
    late ProviderContainer container;

    ConversationState state() => container.read(conversationProvider('p'));
    ConversationNotifier notifier() => container.read(conversationProvider('p').notifier);

    Future<void> open(WidgetTester tester) async {
      api = FakeApi();
      feed = FakeFeed();
      container = ProviderContainer(overrides: [
        conversationApiProvider.overrideWithValue(api),
        realtimeProvider.overrideWithValue(feed),
      ]);
      container.listen(conversationProvider('p'), (_, _) {});
      await notifier().selectSession(_session);
      await tester.pump();
    }

    /// Opens the conversation first, and disposes the container before the
    /// test ends — the notifier's timers must be gone by then.
    void conversationTest(String description, Future<void> Function(WidgetTester tester) body) =>
        testWidgets(description, (tester) async {
          await open(tester);
          await body(tester);
          container.dispose();
        });

    conversationTest('opening reads the conversation and follows the running answer', (tester) async {
      expect(api.reads, 1);
      expect(state().live?.id, _answer);
      expect(state().answering, isTrue);
      expect(state().runningJobId, 'job1');
    });

    conversationTest('frames feed the live answer without rebuilding the conversation', (tester) async {
      final before = state();
      feed.send(wire(text(1, 'Hello', 0)));
      feed.send(wire(step(2, 'Reading', ChatToolStepStatus.running)));
      feed.send(wire(text(3, ' there', 5)));
      feed.send(wire(discard(4)));
      feed.send(wire(text(5, 'Hi', 0)));
      await tester.pump();
      expect(identical(state(), before), isTrue);
      expect(state().live!.text.value, 'Hi');
      expect(state().live!.steps.value.single.summary, 'Reading');
      expect(api.reads, 1);
    });

    conversationTest('a gap in the frames re-reads the conversation', (tester) async {
      feed.send(wire(text(1, 'Hello', 0)));
      feed.send(wire(step(3, 'Reading', ChatToolStepStatus.running)));
      await tester.pump();
      expect(api.reads, 2);
    });

    conversationTest('a beat gone quiet for 30 s re-reads the conversation', (tester) async {
      feed.send(wire(beat(1, 0)));
      await tester.pump(const Duration(seconds: 29));
      expect(api.reads, 1);
      feed.send(wire(beat(2, 0)));
      await tester.pump(const Duration(seconds: 29));
      expect(api.reads, 1, reason: 'the beat came, so the clock started again');
      await tester.pump(const Duration(seconds: 2));
      expect(api.reads, 2);
    });

    conversationTest('a message event for the open conversation re-reads it; an answer landing ends the live one', (tester) async {
      api
        ..status = ConversationStatus.idle
        ..messages = [
          message('u1', ChatRole.user, ChatMessageStatus.answered, text: 'Hello'),
          message(_answer, ChatRole.assistant, ChatMessageStatus.done, text: 'Hi there', seq: 2),
        ];
      feed.send({
        'type': 'project_changes',
        'kind': 'update',
        'entity': 'chat_message',
        'project_id': 'p',
        'id': _answer,
        'session_id': 'another',
        'status': 'done',
      });
      await tester.pump();
      expect(api.reads, 1, reason: 'another conversation is not this one');
      feed.send({
        'type': 'project_changes',
        'kind': 'update',
        'entity': 'chat_message',
        'project_id': 'p',
        'id': _answer,
        'session_id': _session,
        'status': 'done',
      });
      await tester.pump();
      expect(api.reads, 2);
      expect(state().live, isNull);
      expect(state().answering, isFalse);
      expect(state().messages.last.text, 'Hi there');
    });

    conversationTest('a reconnect re-reads the conversation', (tester) async {
      feed.resyncsController.add(null);
      await tester.pump();
      expect(api.reads, 2);
    });

    conversationTest('no message goes while it answers; Stop cancels the answer\'s job', (tester) async {
      expect(await notifier().send('More', const [], null, manuscript: 'write'), isA<SendFailed>());
      expect(api.sentIds, isEmpty);
      await notifier().stop();
      expect(api.stopped, ['job1']);
      expect(state().stopping, isTrue);
    });

    conversationTest('a first message adopts the conversation the server made', (tester) async {
      notifier().newChat();
      expect(state().sessionId, isNull);
      final outcome = await notifier().send('Hello', const [], null, manuscript: 'write');
      await tester.pump();
      expect(outcome, isA<SendDone>());
      expect(state().sessionId, _session);
      expect(state().answering, isTrue);
    });

    conversationTest('a send lost on the network is retried with the same id', (tester) async {
      notifier().newChat();
      api.sendError = ServerError('network_error', 0);
      expect(await notifier().send('Hello', const [], null, manuscript: 'write'), isA<SendFailed>());
      expect(state().error, isNotNull);
      api.sendError = null;
      expect(await notifier().send('Hello', const [], null, manuscript: 'write'), isA<SendDone>());
      await tester.pump();
      expect(api.sentIds, hasLength(2));
      expect(api.sentIds.first, api.sentIds.last);
    });
  });
}
