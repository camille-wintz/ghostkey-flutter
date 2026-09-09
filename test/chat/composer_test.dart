import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/chat/composer.dart';
import 'package:ghostkey/chat/quota_feature.dart';
import 'package:ghostkey/chat/refusals.dart';
import 'package:ghostkey/chat/turn.dart';
import 'package:ghostkey/server/dto/billing.dart';
import 'package:ghostkey/server/dto/chat.dart';
import 'package:ghostkey/server/dto/projects.dart';
import 'package:ghostkey/server/errors.dart';

DocumentSummary doc(String id, String filename, {int? words = 100}) => DocumentSummary(
      id: id,
      kind: DocumentKind.chapter,
      filename: filename,
      version: 1,
      wordCount: words,
      updatedAt: '',
    );

String words(int n) => List.generate(n, (i) => 'w$i').join(' ');

/// A composer over fakes: what was sent, what the gate says, what the turn
/// owner answers.
class Harness {
  Harness({this.exhausted = false, this.outcome = const SendDone(), this.spent = const []});

  bool exhausted;
  SendOutcome outcome;
  final List<String> spent;
  final List<(String, List<ChatAttachment>, String)> sent = [];

  late final ComposerController composer = ComposerController(
    spentIds: () => spent,
    quotaFor: (_) => ChatQuotaFeature(feature: 'phantom_chat', exhausted: exhausted),
    sendTurn: (text, attachments, model) async {
      sent.add((text, attachments, model));
      return outcome;
    },
    isSending: () => false,
  );
}

void main() {
  group('attachments', () {
    test('mint ids across the session, never reusing a spent handle', () {
      final h = Harness(spent: ['a1', 'a2']);
      h.composer.attachChapter(doc('d1', 'One.md'));
      h.composer.attachChapter(doc('d2', 'Two.md'));
      expect(h.composer.attachments.map((a) => a.id), ['a3', 'a4']);
      expect(h.composer.attachedDocumentIds, {'d1', 'd2'});
    });
    test('the same chapter is attached once', () {
      final h = Harness();
      h.composer.attachChapter(doc('d1', 'One.md'));
      h.composer.attachChapter(doc('d1', 'One.md'));
      expect(h.composer.attachments.length, 1);
      expect(h.composer.attachments.single.title, 'One');
    });
    test('a short paste stays text, a long one becomes an attachment', () {
      final h = Harness();
      expect(h.composer.attachPaste('just a line'), isFalse);
      expect(h.composer.attachments, isEmpty);
      expect(h.composer.attachPaste('Title line\n${words(300)}'), isTrue);
      final paste = h.composer.attachments.single as PasteAttachment;
      expect(paste.id, 'a1');
      expect(paste.title, 'Title line');
      expect(paste.words, 302);
    });
    test('the paste interceptor lifts a long insertion out of the field', () {
      final h = Harness();
      const before = TextEditingValue(text: 'ask: ', selection: TextSelection.collapsed(offset: 5));
      final pasted = 'ask: ${words(260)}';
      final after = h.composer.pasteInterceptor.formatEditUpdate(
        before,
        TextEditingValue(text: pasted, selection: TextSelection.collapsed(offset: pasted.length)),
      );
      expect(after.text, 'ask: ');
      expect(after.selection.baseOffset, 5);
      expect(h.composer.attachments.single, isA<PasteAttachment>());
    });
    test('the paste interceptor leaves typing alone', () {
      final h = Harness();
      const before = TextEditingValue(text: 'ab');
      const after = TextEditingValue(text: 'abc');
      expect(h.composer.pasteInterceptor.formatEditUpdate(before, after), after);
      expect(h.composer.attachments, isEmpty);
    });
  });

  group('the quota gate', () {
    test('ahead of the call: a spent counter refuses without sending or clearing', () async {
      final h = Harness(exhausted: true);
      h.composer.text.text = 'hello';
      final refusal = await h.composer.send(model: 'gpt-5-6-terra');
      expect(refusal, isA<QuotaRefusal>());
      expect((refusal! as QuotaRefusal).refused, isNull);
      expect(h.sent, isEmpty);
      expect(h.composer.text.text, 'hello');
    });
    test('a send clears the composer and hands everything to the turn', () async {
      final h = Harness();
      h.composer.text.text = '  hello  ';
      h.composer.attachChapter(doc('d1', 'One.md'));
      final refusal = await h.composer.send(model: 'sonnet-5');
      expect(refusal, isNull);
      expect(h.sent.single.$1, 'hello');
      expect(h.sent.single.$2.single, isA<ChapterAttachment>());
      expect(h.sent.single.$3, 'sonnet-5');
      expect(h.composer.text.text, isEmpty);
      expect(h.composer.attachments, isEmpty);
    });
    test('nothing to send is a no-op', () async {
      final h = Harness();
      expect(await h.composer.send(model: 'gpt-5-6-terra'), isNull);
      expect(h.sent, isEmpty);
      expect(h.composer.canSend, isFalse);
    });
    test("after the call: the server's 402 puts the message back and names its counter", () async {
      final refused = QuotaExceeded(
        feature: 'fable_chat',
        label: 'Fable messages',
        plan: Plan.pro,
        allowance: 5,
        used: 5,
        periodEnd: '2026-09-14T00:00:00Z',
        upgradePlan: null,
        upgradeAllowance: null,
      );
      final h = Harness();
      final attachment = ChapterAttachment(id: 'a1', title: 'One', documentId: 'd1');
      h.outcome = SendRefused(
        ServerError('quota_exceeded', 402, null, null, null, refused),
        'my question',
        [attachment],
      );
      h.composer.text.text = 'my question';
      h.composer.attachChapter(doc('d1', 'One.md'));
      final refusal = await h.composer.send(model: 'fable-5');
      expect(refusal, isA<QuotaRefusal>());
      final quota = refusal! as QuotaRefusal;
      expect(quota.feature, 'fable_chat');
      expect(quota.refused, same(refused));
      expect(h.composer.text.text, 'my question');
      expect(h.composer.attachments.single.id, 'a1');
    });
    test("after the call: the server's 403 is a plan notice with the server's words", () async {
      final h = Harness();
      h.outcome = SendRefused(
        ServerError('plan_insufficient', 403, null, const PlanDenial(label: 'Claude Fable 5', requiredPlan: 'pro')),
        'q',
        const [],
      );
      h.composer.text.text = 'q';
      final refusal = await h.composer.send(model: 'fable-5');
      expect(refusal, isA<PlanDenied>());
      final denied = refusal! as PlanDenied;
      expect(denied.what, 'Claude Fable 5');
      expect(denied.requiredPlan, Plan.pro);
      expect(h.composer.text.text, 'q');
    });
    test('a failed or stopped turn is not a refusal', () async {
      final h = Harness(outcome: const SendFailed());
      h.composer.text.text = 'q';
      expect(await h.composer.send(model: 'gpt-5-6-terra'), isNull);
      expect(h.composer.text.text, isEmpty);
    });
  });

  test('planOrNull reads only the ladder', () {
    expect(planOrNull('pro'), Plan.pro);
    expect(planOrNull('basic'), Plan.basic);
    expect(planOrNull('enterprise'), isNull);
    expect(planOrNull(null), isNull);
  });
}
