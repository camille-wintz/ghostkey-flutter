import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/words.dart';
import '../../../ds/tokens.dart';
import '../../../poltergeist/ledger.dart';
import '../../../poltergeist/providers.dart';
import '../../../server/dto/poltergeist.dart';
import '../../../server/errors.dart';
import '../../../ui/state_screen.dart';
import '../page_header.dart';
import '../project_scope_id.dart';
import 'ledger_row.dart';
import 'ledger_week_header.dart';
import 'word_columns.dart';

/// The daily words ledger, given the full page: today's figure over the
/// 30-day columns, then one ruled row per day, week by week. Counts words
/// put down — added and rewritten land here, cuts don't — so revising still
/// reads as work, but a day of pure cutting reads as quiet.
class WordsTab extends ConsumerWidget {
  const WordsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = projectIdOf(context);
    final stats = ref.watch(wordStatsProvider(projectId));
    final days = stats.value;

    if (days == null) {
      if (stats.hasError) {
        return StateScreen(
          message: "The ledger didn't load.",
          detail: messageFor(stats.error),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(wordStatsProvider(projectId)),
        );
      }
      return const StateScreen(spinner: true, message: 'Reading the ledger…');
    }

    final today = days.isNotEmpty ? days.last : null;
    final peak = weekPeak(days);
    final streak = currentStreak(days);
    final weeks = ledgerWeeks(days);
    final items = <_LedgerItem>[
      for (final week in weeks) ...[
        _WeekItem(week),
        for (final day in week.days) _DayItem(day, isToday: identical(day, today)),
      ],
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      itemCount: 2 + items.length,
      itemBuilder: (context, i) {
        if (i == 0) {
          return PageHeader(
            title: 'Word activity',
            meta: '${formatWords(today?.total ?? 0)} in the manuscript',
          );
        }
        if (i == 1) {
          return _Hero(today: today, streak: streak, days: days);
        }
        return switch (items[i - 2]) {
          _WeekItem(:final week) => LedgerWeekHeader(week: week),
          _DayItem(:final day, :final isToday) => LedgerRow(day: day, peak: peak, isToday: isToday),
        };
      },
    );
  }
}

sealed class _LedgerItem {
  const _LedgerItem();
}

class _WeekItem extends _LedgerItem {
  const _WeekItem(this.week);
  final LedgerWeek week;
}

class _DayItem extends _LedgerItem {
  const _DayItem(this.day, {required this.isToday});
  final WordStatsDay day;
  final bool isToday;
}

/// Today's figure, the streak, and the 30-day columns.
class _Hero extends StatelessWidget {
  const _Hero({required this.today, required this.streak, required this.days});
  final WordStatsDay? today;
  final int streak;
  final List<WordStatsDay> days;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatWords(today?.written ?? 0),
                        style: DsStyle.prose(const DsStep(40, 40)).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                      const SizedBox(height: 8),
                      Text('WORDS TODAY', style: DsStyle.eyebrow()),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    streak > 0 ? '$streak ${streak == 1 ? 'day' : 'days'} running' : 'No streak yet',
                    style: DsStyle.ui(DsText.ui, color: Ds.mid),
                  ),
                ),
              ],
            ),
          ),
          WordColumns(days: days, weekdayLabels: false),
          const SizedBox(height: 28),
        ],
      );
}
