import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/chat/questions.dart';
import 'package:ghostkey/screens/phantom/question_card.dart';
import 'package:ghostkey/server/dto/chat.dart';
import 'package:ghostkey/server/dto/chat_conversation.dart';

const questions = [
  ChatQuestion(question: 'Whose book is it?', options: ['Mara carries it, start to end', 'Two leads, alternating']),
  ChatQuestion(question: 'Where does it end?', options: ['At the wedding', 'A year later']),
  ChatQuestion(question: 'How dark?', options: ['Cosy', 'Grim']),
];

Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 360, child: child))),
    );

/// Every "Other" row makes the card taller than the default 600pt surface.
void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 6000);
  addTearDown(tester.view.reset);
}

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
    test('"Other" answers in the author\'s words, and replaces an option', () {
      var choices = const QuestionChoices().toggle(0, 'Two leads, alternating').toggleOther(0);
      expect(choices[0], isNull);
      expect(choices.isEmpty, isTrue);
      choices = choices.writeOther(0, '  Mara, then her sister  ');
      expect(answersMessage(questions, choices), '1. Mara, then her sister');
      choices = choices.toggle(0, 'Two leads, alternating');
      expect(choices.otherText(0), isNull);
      expect(answersMessage(questions, choices), '1. Two leads, alternating');
    });
  });

  group('wire', () {
    test('an answer reads its questions', () {
      final message = ChatMessage.fromJson({
        'id': 'm2',
        'role': 'assistant',
        'status': 'done',
        'text': 'Three things only you can settle:',
        'questions': [
          {'question': 'Whose book is it?', 'options': ['Mara', 'Both']},
          {'question': 'Anything else?', 'options': <String>[]},
        ],
      });
      expect(message.questions.map((q) => q.question), ['Whose book is it?', 'Anything else?']);
      expect(message.questions.first.options, ['Mara', 'Both']);
      expect(ChatMessage.fromJson({'role': 'assistant', 'text': 'Hi'}).questions, isEmpty);
    });
    test('the open questions are the newest answer\'s, past any tasks', () {
      ChatMessage m(String id, ChatRole role, {bool asks = false}) => ChatMessage(
            id: id,
            sessionId: 's',
            seq: 0,
            role: role,
            status: ChatMessageStatus.done,
            text: '',
            questions: asks ? questions : const [],
          );
      expect(openQuestionsAt([m('1', ChatRole.user), m('2', ChatRole.assistant, asks: true)]), 1);
      expect(openQuestionsAt([m('2', ChatRole.assistant, asks: true), m('3', ChatRole.task)]), 0);
      expect(openQuestionsAt([m('2', ChatRole.assistant, asks: true), m('3', ChatRole.user)]), isNull);
      expect(openQuestionsAt([m('2', ChatRole.assistant)]), isNull);
      expect(openQuestionsAt(const []), isNull);
    });
  });

  group('QuestionCard', () {
    testWidgets('picks one per question and sends the numbered lines', (tester) async {
      tall(tester);
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
    testWidgets('"Other" opens a field whose words are the answer', (tester) async {
      tall(tester);
      String? sent;
      await tester.pumpWidget(host(QuestionCard(questions: questions, onAnswer: (text) => sent = text)));
      expect(find.text('Other'), findsNWidgets(3));
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Other').at(1));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'On the ferry');
      await tester.pump();
      await tester.tap(find.text('SEND ANSWERS'));
      expect(sent, '2. On the ferry');
    });
    testWidgets('read-only draws the questions with no button', (tester) async {
      await tester.pumpWidget(host(const QuestionCard(questions: questions)));
      expect(find.text('1. Whose book is it?'), findsOneWidget);
      expect(find.text('Grim'), findsOneWidget);
      expect(find.text('SEND ANSWERS'), findsNothing);
      expect(find.text('Other'), findsNothing);
    });
  });
}
