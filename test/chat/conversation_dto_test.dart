import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/chat/answer_end.dart';
import 'package:ghostkey/server/dto/chat.dart';
import 'package:ghostkey/server/dto/chat_conversation.dart';
import 'package:ghostkey/server/dto/jobs.dart';
import 'package:ghostkey/server/dto/media.dart';
import 'package:ghostkey/server/dto/realtime.dart';

Map<String, dynamic> row(Map<String, dynamic> fields) => {
      'id': 'm1',
      'session_id': 's1',
      'seq': 1,
      'role': 'assistant',
      'status': 'done',
      'text': '',
      'reply_to': null,
      'job_id': null,
      'error': null,
      'created_at': '2026-09-29T00:00:00Z',
      'updated_at': '2026-09-29T00:00:00Z',
      'finished_at': null,
      ...fields,
    };

void main() {
  group('ChatMessage.fromJson', () {
    test('reads an answer with its steps and receipts', () {
      final m = ChatMessage.fromJson(row({
        'text': 'Done.',
        'job_id': 'j1',
        'steps': [
          {'tool': 'read_outline', 'summary': 'Reading the outline', 'status': 'done'},
          'not a step',
        ],
        'result': {
          'model': 'opus-5-5',
          'switched_from': 'deepseek',
          'savedNotes': [
            {'documentId': 'n1', 'filename': 'Note.md'},
          ],
          'chapterEdits': [
            {'documentId': 'd1', 'filename': 'One.md', 'version': 3, 'created': true},
          ],
          'bibleEdits': <Object>[],
          'planEdits': <Object>[],
          'awaitingApproval': false,
        },
      }));
      expect((m.role, m.status, m.jobId), (ChatRole.assistant, ChatMessageStatus.done, 'j1'));
      expect(m.steps.single.tool, 'read_outline');
      expect(m.result!.model, 'opus-5-5');
      expect(m.result!.switchedFrom, 'deepseek');
      expect(m.result!.savedNotes.single.documentId, 'n1');
      expect(m.result!.edits.chapterEdits.single.created, isTrue);
    });

    test('reads a task with its label and summary', () {
      final m = ChatMessage.fromJson(row({'role': 'task', 'status': 'running', 'label': 'Updating the outline', 'summary': null}));
      expect((m.role, m.status, m.label, m.summary), (ChatRole.task, ChatMessageStatus.running, 'Updating the outline', null));
    });

    test('an unknown role, status or result shape reads quietly', () {
      final m = ChatMessage.fromJson(row({'role': 'narrator', 'status': 'pondering', 'result': 'odd', 'steps': 'odd'}));
      expect(m.role, ChatRole.unknown);
      expect(m.status, ChatMessageStatus.unknown);
      expect(m.result, isNull);
      expect(m.steps, isEmpty);
      expect(ChatMessage.fromJson(row({'status': null})).status, ChatMessageStatus.unknown);
    });
  });

  test('the conversation read and the send result tolerate new values', () {
    final session = {'id': 's1', 'title': 'Hi', 'messages': <Object>[], 'version': 1};
    final read = ChatConversation.fromJson({
      'session': session,
      'status': 'thinking-hard',
      'messages': [row({'status': 'running'})],
    });
    expect(read.status, ConversationStatus.idle);
    expect(read.messages.single.isRunningAnswer, isTrue);
    expect(ChatConversation.fromJson({'session': session, 'status': 'queued', 'messages': <Object>[]}).status, ConversationStatus.queued);

    final sent = ChatSendResult.fromJson({'status': 'answering', 'message': row({'role': 'user', 'status': 'queued'}), 'session': session});
    expect((sent.status, sent.session?.id), (ChatSendStatus.answering, 's1'));
    final odd = ChatSendResult.fromJson({'status': 'teleported', 'message': row({}), 'session': null});
    expect((odd.status, odd.session), (ChatSendStatus.unknown, null));
  });

  test('a session summary reads its status, idle when it is missing or new', () {
    expect(ChatSessionSummary.fromJson({'id': 's', 'status': 'running'}).status, ConversationStatus.running);
    expect(ChatSessionSummary.fromJson({'id': 's'}).status, ConversationStatus.idle);
    expect(ChatSessionSummary.fromJson({'id': 's', 'status': 'paused'}).status, ConversationStatus.idle);
  });

  group('realtime', () {
    test('only project changes are events', () {
      expect(ProjectChangeEvent.fromJson({'type': 'ping'}), isNull);
      expect(ProjectChangeEvent.fromJson('text'), isNull);
      final job = ProjectChangeEvent.fromJson({
        'type': 'project_changes',
        'kind': 'update',
        'entity': 'job',
        'project_id': 'p',
        'id': 'j1',
        'job': {'status': 'done'},
      })!;
      expect((job.entity, job.id, job.jobStatus), ('job', 'j1', JobStatus.done));
    });

    test('a chat_message event reads without its text', () {
      final e = ChatMessageEvent.fromJson({'session_id': 's1', 'id': 'm1', 'role': 'assistant', 'status': 'done', 'kind': 'update'});
      expect((e.sessionId, e.role, e.status), ('s1', ChatRole.assistant, ChatMessageStatus.done));
    });

    test('chat_stream frames read by their one content field', () {
      ChatStreamFrame frame(Map<String, dynamic> f) => ChatStreamFrame.fromJson({'session_id': 's1', 'id': 'a1', 'n': 4, ...f});
      expect(frame({'text': 'Hi', 'at': 7}), isA<StreamText>().having((f) => f.at, 'at', 7).having((f) => f.n, 'n', 4));
      expect(frame({'text': 'Hi'}), isA<StreamText>().having((f) => f.at, 'at', null));
      expect(frame({'discard': true}), isA<StreamDiscard>());
      expect(
        frame({'step': {'tool': 'save_note', 'summary': 'Saving', 'status': 'weird'}}),
        isA<StreamStep>().having((f) => f.step.status, 'status', ChatToolStepStatus.running),
      );
      expect(frame({'view': {'kind': 'hologram'}}), isA<StreamView>().having((f) => f.view, 'view', null));
      expect(
        frame({'phase': 'daydreaming', 'elapsed_ms': 10000, 'steps': 2, 'text_length': 40}),
        isA<StreamBeat>().having((f) => f.phase, 'phase', AnswerPhase.unknown).having((f) => f.textLength, 'text', 40),
      );
      expect(frame({'sparkle': true}), isA<StreamOther>());
    });
  });

  group('answerEndLine', () {
    ChatMessage answer(String status, {String? error, String text = 'Some words'}) =>
        ChatMessage.fromJson(row({'status': status, 'error': error, 'text': text}));

    test('says nothing for a finished or running answer', () {
      expect(answerEndLine(answer('done')), isNull);
      expect(answerEndLine(answer('running')), isNull);
    });

    test('words a stop, a cut-off and a refusal without the wire code', () {
      expect(answerEndLine(answer('stopped')), 'Stopped here.');
      expect(answerEndLine(answer('stopped', text: '')), 'Stopped before it said anything.');
      final lines = [
        answerEndLine(answer('error', error: 'interrupted')),
        answerEndLine(answer('error', error: 'quota_exceeded')),
        answerEndLine(answer('error', error: 'plan_insufficient')),
        answerEndLine(answer('error', error: 'model_overloaded_xyz')),
      ];
      expect(lines, everyElement(isNotNull));
      expect(lines.join(), isNot(contains('_')));
    });
  });

  group('ChatView.fromJson', () {
    test('reads a picture view by its item id', () {
      final view = ChatView.fromJson({'kind': 'image', 'id': 'item-1', 'title': 'The mill'})!;
      expect(view.kind, ChatViewKind.image);
      expect(view.id, 'item-1');
    });

    test('reads a kind it does not know as nothing open', () {
      expect(ChatView.fromJson({'kind': 'hologram', 'id': 'x'}), isNull);
    });
  });

  test('MediaItem reads its series, asset and preview', () {
    final item = MediaItem.fromJson({
      'id': 'i',
      'series_id': 's',
      'kind': 'image',
      'title': 'The mill',
      'body': 'A mill at dusk.',
      'body_chars': 15,
      'asset_id': 'a',
      'meta': {'width': 800, 'height': 600, 'preview_asset_id': 'p'},
      'origin': 'author',
    });
    expect((item.seriesId, item.assetId, item.previewAssetId, item.isImage), ('s', 'a', 'p', true));
    expect(MediaItem.fromJson({'id': 'i', 'kind': 'text', 'asset_id': null, 'meta': <String, dynamic>{}}).assetId, isNull);
  });
}
