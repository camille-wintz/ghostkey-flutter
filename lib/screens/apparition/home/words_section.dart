import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/words.dart';
import '../../../ds/tokens.dart';
import '../../../rewards/ledger.dart';
import '../../../rewards/providers.dart';
import '../../../rewards/week_line.dart';
import 'daily_target_row.dart';
import 'home_section.dart';
import 'word_columns.dart';
import 'word_range_switch.dart';

/// The author's words over a week, a month or a year — what Poltergeist's
/// week columns and its words page were, in one section. Counts words put
/// down: added and rewritten land here, cuts don't, so revising still reads
/// as work.
///
/// The AUTHOR's, not this book's: the columns, the streak and the ticks all
/// read every book added up, the same figure the daily target is measured
/// against. The week and month share one 30-day read; the year asks for its
/// 365 days only while it is the one shown.
class WordsSection extends ConsumerStatefulWidget {
  const WordsSection({super.key});

  @override
  ConsumerState<WordsSection> createState() => _WordsSectionState();
}

class _WordsSectionState extends ConsumerState<WordsSection> {
  WordRange _range = WordRange.week;

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(rewardsProvider(ledgerDays));
    final rewards = ledger.value;
    final shown = _range == WordRange.year ? ref.watch(rewardsProvider(yearDays)) : ledger;
    final columns = shown.value == null
        ? null
        : wordColumns(shown.value!.days, _range, shown.value!.metDays.toSet());
    final streak = rewards == null ? 0 : currentStreak(rewards.days);

    return HomeSection(
      eyebrow: 'Words',
      action: columns == null
          ? null
          : Text(
              '${formatWords(columnsTotal(columns))} words'.toUpperCase(),
              style: DsStyle.eyebrow(color: Ds.faint).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WordRangeSwitch(value: _range, onChanged: (range) => setState(() => _range = range)),
          const SizedBox(height: 16),
          if (columns != null)
            WordColumns(
              columns: columns,
              showValues: _range == WordRange.week,
              labelEvery: _range == WordRange.month ? 5 : 1,
            )
          else
            SectionNote(shown.hasError ? "The ledger didn't load." : 'Loading…'),
          if (rewards != null) ...[
            const SizedBox(height: 16),
            Text(
              '${formatWords(rewards.writtenToday)} today · '
              '${streak > 0 ? '$streak ${streak == 1 ? 'day' : 'days'} running' : 'no streak yet'}',
              style: DsStyle.ui(DsText.ui, color: Ds.mid).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 4),
            Text(weekLine(rewards), style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
            const SizedBox(height: 16),
            DailyTargetRow(target: rewards.target, writtenToday: rewards.writtenToday),
          ],
        ],
      ),
    );
  }
}
