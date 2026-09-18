import 'json.dart';

// The writing rewards' wire shapes — `Rewards`, `RewardClaim`, `Reward`,
// `RewardWeek` and `Cat` in openapi.yaml. The server decides every reward;
// these only carry what it decided.

/// A cat the author has earned. [svg] is the whole picture, self-contained,
/// for `SvgPicture.string`; [catId] names the catalogue entry it was drawn
/// from.
class Cat {
  const Cat({
    required this.id,
    required this.catId,
    required this.name,
    required this.svg,
    required this.earnedAt,
    required this.projectId,
    required this.weekStart,
  });

  final String id;
  final String catId;
  final String name;
  final String svg;
  final String earnedAt;

  /// The book it was earned in, or null once that book is deleted.
  final String? projectId;

  /// Monday of the local week it was earned in, `YYYY-MM-DD`.
  final String weekStart;

  static Cat fromJson(Json json) => Cat(
        id: asString(json['id']),
        catId: asString(json['cat_id']),
        name: asString(json['name']),
        svg: asString(json['svg']),
        earnedAt: asString(json['earned_at']),
        projectId: json['project_id'] as String?,
        weekStart: asString(json['week_start']),
      );
}

/// Where the current local week stands against its cat.
class RewardWeek {
  const RewardWeek({required this.start, required this.ticked, required this.required, required this.catEarned});

  /// Monday, `YYYY-MM-DD`.
  final String start;

  /// Days of this week whose writing reached the daily target.
  final int ticked;

  /// Ticks a week needs to earn a cat.
  final int required;
  final bool catEarned;

  static RewardWeek fromJson(Json json) => RewardWeek(
        start: asString(json['start']),
        ticked: asInt(json['ticked']),
        required: asInt(json['required']),
        catEarned: asBool(json['cat_earned']),
      );
}

/// One thing a claim just awarded.
sealed class Reward {
  const Reward();

  static Reward? fromJson(Json json) => switch (json['kind']) {
        'words' => WordsReward(asInt(json['words'])),
        'day' => DayReward(daysToCat: asInt(json['days_to_cat'])),
        'cat' => CatReward(Cat.fromJson(asJson(json['cat']))),
        // A kind this build does not know is not an error: the server may
        // grow a reward before the app does.
        _ => null,
      };
}

/// A word milestone reached today.
class WordsReward extends Reward {
  const WordsReward(this.words);
  final int words;
}

/// Today's tick, and how many more ticked days this week needs for a cat.
class DayReward extends Reward {
  const DayReward({required this.daysToCat});
  final int daysToCat;
}

/// The cat itself.
class CatReward extends Reward {
  const CatReward(this.cat);
  final Cat cat;
}

/// What a claim found: where today stands, and anything it just awarded.
class RewardClaim {
  const RewardClaim({
    required this.writtenToday,
    required this.target,
    required this.metToday,
    required this.week,
    required this.awarded,
  });

  final int writtenToday;
  final int? target;
  final bool metToday;
  final RewardWeek week;
  final List<Reward> awarded;

  static RewardClaim fromJson(Json json) => RewardClaim(
        writtenToday: asInt(json['written_today']),
        target: json['target'] as int?,
        metToday: asBool(json['met_today']),
        week: RewardWeek.fromJson(asJson(json['week'])),
        awarded: asJsonList(json['awarded']).map(Reward.fromJson).nonNulls.toList(),
      );
}

/// The ledger's view: which days in the window are ticked, and the week.
class Rewards {
  const Rewards({required this.target, required this.metDays, required this.week, required this.catsEarned});

  final int? target;

  /// The ticked days in the window, `YYYY-MM-DD`, oldest first.
  final List<String> metDays;
  final RewardWeek week;

  /// How many cats the author has, across every book.
  final int catsEarned;

  static Rewards fromJson(Json json) => Rewards(
        target: json['target'] as int?,
        metDays: asStringList(json['met_days']),
        week: RewardWeek.fromJson(asJson(json['week'])),
        catsEarned: asInt(json['cats_earned']),
      );
}
