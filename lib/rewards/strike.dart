import '../server/dto/rewards.dart';

// One reward struck like a coin: what the card says and shows. Mirrors the
// desktop's `shared/rewards/copy.ts` — the server decided the reward, this
// only puts it into words and a ring.

/// The word marks a day can strike, lowest first — the server's
/// `WORD_MILESTONES`, copied so the card can say what the next one is and
/// how far the ring has to close. The server decides when one is struck;
/// this only names the one after it.
const List<int> _wordMilestones = [100, 500];

/// The week the chain draws: Monday to Sunday.
const int chainDays = 7;

class Strike {
  const Strike({
    this.cat,
    required this.eyebrow,
    required this.headline,
    required this.sub,
    required this.short,
    required this.footnote,
    required this.ring,
    required this.ticked,
  });

  /// The cat, when the thing struck is one. A mark shows Poltergeist's glyph.
  final Cat? cat;
  final String eyebrow;
  final String headline;
  final String sub;

  /// [sub] in one line, for the compact card: the thing worth knowing with
  /// the sentence around it cut away. The headline already says the number.
  final String short;

  /// Under the chain, in small caps.
  final String footnote;

  /// How far the ring closes, 0–1: to the next mark for a word count, all
  /// the way for a goal met or a cat earned.
  final double ring;

  /// Ticked days this week, lit along the chain; null when there is no
  /// target to tick against, and the chain stays off the card.
  final int? ticked;
}

const List<String> _count = ['no', 'one', 'two', 'three', 'four', 'five', 'six', 'seven'];

/// A small number as a word, for the middle of a sentence.
String _asWord(int n) => n >= 0 && n < _count.length ? _count[n] : '$n';

String _grouped(int n) {
  final digits = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

Strike strikeFor(Reward reward, RewardClaim claim) {
  final ticked = claim.target == null ? null : claim.week.ticked;
  switch (reward) {
    case WordsReward(:final words):
      final next = _wordMilestones.where((mark) => mark > words).firstOrNull;
      final target = claim.target;
      final toGoal = target != null && !claim.metToday
          ? target - claim.writtenToday
          : 0;
      final sub = [
        words >= 500
            ? "${_grouped(words)} words written already. You're doing amazing!"
            : "${_grouped(words)} words written today! You're on your way.",
        if (toGoal > 0) '${_grouped(toGoal)} more to your daily goal.',
      ].join(' ');
      return Strike(
        eyebrow: 'Today',
        headline: '${_grouped(words)} words',
        sub: sub,
        short: toGoal > 0
            ? '${_grouped(toGoal)} more to your daily goal.'
            : (words >= 500 ? "You're doing amazing!" : "You're on your way."),
        footnote: next != null
            ? 'Next at ${_grouped(next)}'
            : 'Kept in Poltergeist',
        ring: next != null
            ? (claim.writtenToday / next).clamp(0, 1).toDouble()
            : 1,
        ticked: ticked,
      );
    case DayReward(:final daysToCat):
      return Strike(
        eyebrow: 'Daily goal',
        headline: 'Day ${claim.week.ticked}',
        sub: daysToCat > 0
            ? "Congratulations! You've completed your daily goal. Keep writing for ${_asWord(daysToCat)} more ${daysToCat == 1 ? 'day' : 'days'} and you'll get a cat."
            // A day with nothing left to count down to: the week's cat is
            // already on the shelf, since a tick that earns one is sent as
            // the cat itself, never as a day.
            : "Congratulations! You've completed your daily goal. This week's cat is already yours.",
        short: daysToCat > 0
            ? "Daily goal done. ${_asWord(daysToCat)} more ${daysToCat == 1 ? 'day' : 'days'} to a cat."
            : "Daily goal done. This week's cat is already yours.",
        footnote: 'Kept in Poltergeist',
        ring: 1,
        ticked: ticked,
      );
    case CatReward(:final cat):
      // A cat stands in for the tick that earned it, so the welcome one has
      // to say the goal was reached — it is the only notice the author gets.
      final first = cat.reason == CatReason.firstGoal;
      return Strike(
        cat: cat,
        eyebrow: first ? 'Your first goal' : 'A full week',
        headline: cat.name,
        sub: first
            ? "You've reached your daily goal for the first time! Here is a cat as a well-earned reward."
            : "You've completed your weekly goal! Here is a cat for your trouble.",
        short: first
            ? 'Your first daily goal, and a cat for it.'
            : 'A full week of writing, and a cat for it.',
        footnote: 'Added to Poltergeist',
        ring: 1,
        ticked: ticked,
      );
  }
}
