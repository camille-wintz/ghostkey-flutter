import '../server/dto/chat.dart';

// The answers to a turn that stopped to ask: one pick per question, by
// question position, and the message those picks become. The message is an
// ordinary user turn — the model reads the numbers against the questions it
// asked, which ride on its own message in the transcript.

/// The answer picked for each question, keyed by the question's 0-based
/// position: a suggested option, or "Other" with the author's own words
/// (held in [other]). Immutable; the card holds one and swaps it on each tap
/// or keystroke.
class QuestionChoices {
  const QuestionChoices([this.picked = const {}, this.other = const {}]);
  final Map<int, String> picked;
  final Map<int, String> other;

  /// Nothing that would send: no option, and no "Other" with words in it.
  bool get isEmpty => picked.isEmpty && other.values.every((text) => text.trim().isEmpty);

  String? operator [](int question) => picked[question];

  /// The words typed under "Other", or null when "Other" isn't picked.
  String? otherText(int question) => other[question];

  /// Pick `option` for `question`; picking the one already picked clears it.
  QuestionChoices toggle(int question, String option) => picked[question] == option
      ? QuestionChoices({...picked}..remove(question), other)
      : QuestionChoices({...picked, question: option}, {...other}..remove(question));

  /// Pick "Other" for `question`; picking it again closes it.
  QuestionChoices toggleOther(int question) => other.containsKey(question)
      ? QuestionChoices(picked, {...other}..remove(question))
      : QuestionChoices({...picked}..remove(question), {...other, question: ''});

  QuestionChoices writeOther(int question, String text) => QuestionChoices(picked, {...other, question: text});
}

/// One line per answered question, `"{n}. {answer}"` with n the question's
/// 1-based position, so a skipped question leaves a gap rather than
/// renumbering the rest. An "Other" left empty answers nothing. Empty when
/// nothing is picked.
String answersMessage(List<ChatQuestion> questions, QuestionChoices choices) => [
      for (var i = 0; i < questions.length; i++)
        if (choices[i] ?? choices.otherText(i)?.trim() case final answer? when answer.isNotEmpty) '${i + 1}. $answer',
    ].join('\n');
