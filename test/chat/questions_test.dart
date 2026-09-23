import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/chat/questions.dart';
import 'package:ghostkey/screens/phantom/question_card.dart';
import 'package:ghostkey/server/dto/chat.dart';

const questions = [
  ChatQuestion(question: 'Whose book is it?', options: ['Mara carries it, start to end', 'Two leads, alternating']),
  ChatQuestion(question: 'Where does it end?', options: ['At the wedding', 'A year later']),
  ChatQuestion(question: 'How dark?', options: ['Cosy', 'Grim']),
];

Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 360, child: child))),
    );

void main() {
  group('answersMessage', () {
    test('one numbered line per answered question, gaps kept', () {
      final choices = const QuestionChoices().toggle(0, 'Two leads, alternating').toggle(2, 'Grim');
      expect(answersMessage(questions, choices), '1. Two leads, alternating\n3. Grim');
    });
    test('a second tap clears, another option replaces', () {
      var choices = const QuestionChoices().toggle(1, 'At the wedding');
      choices = choices.toggle(1, 'A year later');
      expect(choices[1], 'A year later');
      choices = choices.toggle(1, 'A year later');
      expect(choices.isEmpty, isTrue);
      expect(answersMessage(questions, choices), '');
    });
  });

  group('wire', () {
    test('a saved assistant message keeps its questions both ways', () {
      final json = {
        'role': 'assistant',
        'text': 'Three things only you can settle:',
        'questions': [
          {'question': 'Whose book is it?', 'options': ['Mara', 'Both']},
          {'question': 'Anything else?', 'options': <String>[]},
        ],
      };
      final message = ChatMessage.fromJson(json);
      expect(message.questions.map((q) => q.question), ['Whose book is it?', 'Anything else?']);
      expect(message.questions.first.options, ['Mara', 'Both']);
      expect(message.toJson(), json);
    });
    test('a message without questions sends no key', () {
      final message = ChatMessage.fromJson({'role': 'assistant', 'text': 'Hi'});
      expect(message.questions, isEmpty);
      expect(message.toJson().containsKey('questions'), isFalse);
    });
    test("the result frame's plan carries the questions", () {
      final result = ChatTurnResult.fromJson({
        'answer': 'Settle these:',
        'plan': {
          'say': 'Settle these:',
          'steps': <Object>[],
          'questions': [
            {'question': 'How dark?', 'options': ['Cosy', 'Grim']},
          ],
          'needsYes': false,
        },
        'steps': <Object>[],
        'savedNotes': <Object>[],
        'session': null,
      });
      expect(result.questions.single.options, ['Cosy', 'Grim']);
      expect(ChatTurnResult.fromJson({'answer': 'x', 'session': null}).questions, isEmpty);
    });
  });

  group('QuestionCard', () {
    testWidgets('picks one per question and sends the numbered lines', (tester) async {
      String? sent;
      await tester.pumpWidget(host(QuestionCard(questions: questions, onAnswer: (text) => sent = text)));
      await tester.tap(find.text('SEND ANSWERS'));
      expect(sent, isNull);
      await tester.tap(find.text('Mara carries it, start to end'));
      await tester.tap(find.text('Grim'));
      await tester.pump();
      await tester.tap(find.text('SEND ANSWERS'));
      expect(sent, '1. Mara carries it, start to end\n3. Grim');
    });
    testWidgets('read-only draws the questions with no button', (tester) async {
      await tester.pumpWidget(host(const QuestionCard(questions: questions)));
      expect(find.text('1. Whose book is it?'), findsOneWidget);
      expect(find.text('Grim'), findsOneWidget);
      expect(find.text('SEND ANSWERS'), findsNothing);
    });
  });
}
