import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/screens/account/delete_account_dialog.dart';
import 'package:ghostkey/ui/button.dart';
import 'package:ghostkey/ui/field.dart';

Finder _button(String label) => find.byWidgetPredicate((w) => w is GkButton && w.label == label);

Future<Future<bool>> _open(WidgetTester tester) async {
  late Future<bool> answer;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () => answer = confirmDeleteAccount(context, email: 'a@b.c', hasLiveSubscription: true),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return answer;
}

void main() {
  testWidgets('the warning comes first and can be backed out of', (tester) async {
    final answer = await _open(tester);
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.textContaining('subscription ends today'), findsOneWidget);
    expect(find.byType(GkField), findsNothing);

    await tester.tap(_button('Keep my account'));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);
  });

  testWidgets('delete resolves true only once DELETE is typed', (tester) async {
    final answer = await _open(tester);
    await tester.tap(_button('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'DELE');
    await tester.pump();
    await tester.tap(_button('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('This can\'t be undone'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.tap(_button('Delete account'));
    await tester.pumpAndSettle();
    expect(await answer, isTrue);
  });
}
