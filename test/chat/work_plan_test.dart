import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/chat/drawer_entries.dart';
import 'package:ghostkey/server/chat/api.dart';
import 'package:ghostkey/server/dto/chat.dart';
import 'package:ghostkey/server/dto/work_plan.dart';

void main() {
  group('WorkPlan DTOs', () {
    test('reads a plan with its text and version', () {
      final plan = WorkPlan.fromJson({
        'id': 'p1',
        'project_id': 'b1',
        'name': 'Act two',
        'text': '## Goal\nFix the sag.',
        'version': 3,
        'created_at': '2026-09-28T10:00:00Z',
        'updated_at': '2026-09-28T11:00:00Z',
      });
      expect((plan.id, plan.projectId, plan.name, plan.version), ('p1', 'b1', 'Act two', 3));
      expect(plan.text, startsWith('## Goal'));
    });

    test('reads a summary with the conversations under it', () {
      final summary = WorkPlanSummary.fromJson({
        'id': 'p1',
        'name': 'Act two',
        'goal': 'Fix the sag.',
        'version': 3,
        'updated_at': '2026-09-28T11:00:00Z',
        'sessions': [
          {'id': 's1', 'title': 'Midpoint', 'updated_at': '2026-09-28T11:00:00Z'},
        ],
      });
      expect(summary.goal, 'Fix the sag.');
      expect(summary.sessions.single.title, 'Midpoint');
      expect(WorkPlanSummary.fromJson({'id': 'p2', 'name': 'x'}).sessions, isEmpty);
    });
  });

  group('work plan on the chat wire', () {
    test('a session reads its plan, and none from null or an older server', () {
      expect(ChatSessionSummary.fromJson({'id': 's', 'work_plan_id': 'p1'}).workPlanId, 'p1');
      expect(ChatSessionSummary.fromJson({'id': 's', 'work_plan_id': null}).workPlanId, isNull);
      expect(ChatSession.fromJson({'id': 's', 'work_plan_id': 'p1', 'messages': <Object>[]}).workPlanId, 'p1');
      expect(ChatSession.fromJson({'id': 's', 'messages': <Object>[]}).workPlanId, isNull);
    });

    test("an answer's receipts read workPlanId in camelCase", () {
      expect(ChatAnswerResult.fromJson({'workPlanId': 'p1'})!.workPlanId, 'p1');
      expect(ChatAnswerResult.fromJson({'workPlanId': null})!.workPlanId, isNull);
      expect(ChatAnswerResult.fromJson(<String, dynamic>{})!.workPlanId, isNull);
    });

    test('a work_plan view round-trips under its wire name', () {
      final view = ChatView.fromJson({'kind': 'work_plan', 'id': 'p1', 'title': 'Act two'})!;
      expect(view.kind, ChatViewKind.workPlan);
      expect(view.toJson(), {'kind': 'work_plan', 'id': 'p1', 'title': 'Act two'});
    });

    test('an unknown kind still reads as nothing open', () {
      expect(ChatView.fromJson({'kind': 'workPlan', 'id': 'p1'}), isNull);
      expect(ChatView.fromJson({'kind': 'séance'}), isNull);
    });

    test('a first message carries the plan beside its view; a later one neither', () {
      const view = ChatView(kind: ChatViewKind.workPlan, id: 'p1', title: 'Act two');
      final first = sendMessageBody(id: 'm1', text: 'Go', manuscript: 'write', view: view, workPlanId: 'p1');
      expect(first['work_plan_id'], 'p1');
      expect(first['view'], {'kind': 'work_plan', 'id': 'p1', 'title': 'Act two'});
      expect(first.containsKey('session_id'), isFalse);
      final later =
          sendMessageBody(id: 'm2', sessionId: 's', text: 'Go', manuscript: 'write', view: view, workPlanId: 'p1');
      expect(later.keys, containsAll(['id', 'session_id', 'text', 'manuscript', 'views']));
      expect(later.containsKey('work_plan_id'), isFalse);
      expect(later.containsKey('view'), isFalse);
    });
  });

  group('drawerEntries', () {
    ChatSessionSummary session(String id, {String? plan}) =>
        ChatSessionSummary(id: id, title: id, version: 1, updatedAt: '', workPlanId: plan);

    test('no plans: the chats as they were', () {
      final entries = drawerEntries(const [], [session('a'), session('b')]);
      expect(entries.map((e) => (e as DrawerSession).session.id), ['a', 'b']);
    });

    test('a conversation under a plan is listed there once, not loose', () {
      const plan = WorkPlanSummary(
        id: 'p1',
        name: 'Act two',
        goal: '',
        version: 1,
        updatedAt: '',
        sessions: [WorkPlanSessionRef(id: 'a', title: 'a', updatedAt: '')],
      );
      final entries = drawerEntries(const [plan], [session('a', plan: 'p1'), session('b')]);
      expect(entries.map((e) => switch (e) {
            DrawerHeading(:final label) => 'h:$label',
            DrawerPlan(:final plan) => 'p:${plan.id}',
            DrawerSession(:final session, :final nested) => '${nested ? 'n' : 's'}:${session.id}',
          }), ['h:Plans', 'p:p1', 'n:a', 'h:Chats', 's:b']);
    });
  });
}
