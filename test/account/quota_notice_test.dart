import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/access/quota_refusals.dart';
import 'package:ghostkey/screens/account/quota_notice.dart';
import 'package:ghostkey/server/dto/billing.dart';
import 'package:ghostkey/server/errors.dart';
import 'package:ghostkey/ui/button.dart';

QuotaExceeded _refused({
  String feature = 'edit_pass',
  String label = 'Proofreads and line edits',
  int allowance = 3,
  int used = 3,
  QuotaUnit unit = QuotaUnit.runs,
}) => QuotaExceeded(
  feature: feature,
  label: label,
  plan: Plan.free,
  allowance: allowance,
  used: used,
  periodEnd: '2026-09-29T00:00:00Z',
  upgradePlan: null,
  upgradeAllowance: null,
  unit: unit,
);

Future<void> _open(WidgetTester tester, {FeatureQuota? snapshot, required QuotaExceeded refused}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showQuotaNotice(context, snapshot: snapshot, refused: refused),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('says the quota is used up, with the counter and the web link', (tester) async {
    await _open(tester, refused: _refused());
    expect(find.text('QUOTA USED UP'), findsOneWidget);
    expect(find.text("You've used up your proofreads and line edits this week"), findsOneWidget);
    expect(find.text('Proofreads and line edits'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('Resets on 29 September 2026'), findsOneWidget);
    expect(find.textContaining('Manage your account options', findRichText: true), findsOneWidget);

    await tester.tap(find.byWidgetPredicate((w) => w is GkButton && w.label == 'Got it'));
    await tester.pumpAndSettle();
    expect(find.text('QUOTA USED UP'), findsNothing);
  });

  testWidgets('dictation counts in minutes', (tester) async {
    await _open(
      tester,
      refused: _refused(feature: 'dictation', label: 'Dictation', allowance: 3600, used: 3600, unit: QuotaUnit.seconds),
    );
    expect(find.text('1 h / 1 h'), findsOneWidget);
  });

  test('only a 402 is reported', () async {
    final reports = <QuotaRefusalReport>[];
    final sub = quotaRefusals.listen(reports.add);
    expect(reportQuotaRefusal(ServerError('plan_insufficient', 403)), isFalse);
    expect(reportQuotaRefusal(StateError('x')), isFalse);
    expect(reportQuotaRefusal(ServerError('quota_exceeded', 402, null, null, null, _refused())), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(reports.single.feature, 'edit_pass');
    await sub.cancel();
  });
}
