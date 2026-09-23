import '../server/dto/chat.dart';

// The answers to a turn that stopped to ask: one pick per question, by
// question position, and the message those picks become. The message is an
// ordinary user turn — the model reads the numbers against the questions it
// asked, which ride on its own message in the transcript.

/// The option picked for each question, keyed by the question's 0-based
/// position. Immutable; the card holds one and swaps it on each tap.
class QuestionChoices {
  const QuestionChoices([this.picked = const {}]);
  final Map<int, String> picked;

  bool get isEmpty => picked.isEmpty;

  String? operator [](int question) => picked[question];

  /// Pick `option` for `question`; picking the one already picked clears it.
  QuestionChoices toggle(int question, String option) => picked[question] == option
      ? QuestionChoices({...picked}..remove(question))
      : QuestionChoices({...picked, question: option});
}

/// One line per answered question, `"{n}. {option}"` with n the question's
/// 1-based position, so a skipped question leaves a gap rather than
/// renumbering the rest. Empty when nothing is picked.
String answersMessage(List<ChatQuestion> questions, QuestionChoices choices) => [
      for (var i = 0; i < questions.length; i++)
        if (choices[i] case final option?) '${i + 1}. $option',
    ].join('\n');
