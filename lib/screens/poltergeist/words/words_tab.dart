import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/words.dart';
import '../../../ds/tokens.dart';
import '../../../poltergeist/ledger.dart';
import '../../../poltergeist/providers.dart';
import '../../../poltergeist/rewards.dart';
import '../../../server/dto/rewards.dart';
import '../../../server/rewards/api.dart';
import '../../../ui/field.dart';
import '../../../server/dto/poltergeist.dart';
import '../../../server/errors.dart';
import '../../../ui/state_screen.dart';
import 'ledger_row.dart';
import 'ledger_week_header.dart';
import 'word_columns.dart';

/// The daily words ledger, given the full page: today's figure over the
/// 30-day columns, then one ruled row per day, week by week. Counts words
/// put down — added and rewritten land here, cuts don't — so revising still
/// reads as work, but a day of pure cutting reads as quiet.
///
/// The whole page is the AUTHOR's, not this book's: the columns, the rows,
/// the streak and the ticks all read every book added up, the same figure
/// the daily target is measured against.
class WordsTab extends ConsumerWidget {
  const WordsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(rewardsProvider);
    final rewards = ledger.value;
    final days = rewards?.days;
    final metDays = rewards?.metDays.toSet() ?? const <String>{};

    if (days == null) {
      if (ledger.hasError) {
        return StateScreen(
          message: "The ledger didn't load.",
          detail: messageFor(ledger.error),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(rewardsProvider),
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
      itemCount: 1 + items.length,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _Hero(today: today, streak: streak, days: days, rewards: rewards, metDays: metDays);
        }
        return switch (items[i - 1]) {
          _WeekItem(:final week) => LedgerWeekHeader(week: week),
          _DayItem(:final day, :final isToday) =>
            LedgerRow(day: day, peak: peak, isToday: isToday, met: metDays.contains(day.day)),
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

/// Today's figure, the streak, the week's standing against its cat, the
/// daily target, and the 30-day columns.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.today,
    required this.streak,
    required this.days,
    required this.rewards,
    required this.metDays,
  });
  final WordStatsDay? today;
  final int streak;
  final List<WordStatsDay> days;
  final Rewards? rewards;
  final Set<String> metDays;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        streak > 0 ? '$streak ${streak == 1 ? 'day' : 'days'} running' : 'No streak yet',
                        style: DsStyle.ui(DsText.ui, color: Ds.mid),
                      ),
                      if (rewards != null) ...[
                        const SizedBox(height: 4),
                        Text(weekLine(rewards!), textAlign: TextAlign.right, style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (rewards != null) ...[
            _TargetRow(target: rewards!.target, writtenToday: rewards!.writtenToday),
            const SizedBox(height: 20),
          ],
          WordColumns(days: days, weekdayLabels: false, metDays: metDays),
          const SizedBox(height: 28),
        ],
      );
}

/// The words a day the author aims for, set in place under the figure. One
/// target for the account: every book's words count towards it, so the line
/// under the label says how today stands across all of them. Saves on submit;
/// an emptied field clears the target. The server answers back through the
/// rewards read, so the field follows it.
class _TargetRow extends ConsumerStatefulWidget {
  const _TargetRow({required this.target, required this.writtenToday});
  final int? target;
  final int writtenToday;

  @override
  ConsumerState<_TargetRow> createState() => _TargetRowState();
}

class _TargetRowState extends ConsumerState<_TargetRow> {
  late final TextEditingController _controller = TextEditingController(text: _text(widget.target));
  bool _saving = false;

  static String _text(int? target) => target == null ? '' : '$target';

  @override
  void didUpdateWidget(_TargetRow old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) _controller.text = _text(widget.target);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _commit(String raw) async {
    final trimmed = raw.trim();
    final next = trimmed.isEmpty ? null : int.tryParse(trimmed);
    if (trimmed.isNotEmpty && (next == null || next < 1)) {
      _controller.text = _text(widget.target);
      return;
    }
    if (next == widget.target) return;
    setState(() => _saving = true);
    try {
      await setMyDailyTarget(next);
      ref.invalidate(rewardsProvider);
    } catch (e) {
      debugPrint('[rewards] daily target save failed: $e');
      _controller.text = _text(widget.target);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _acrossBooks => widget.target == null
      ? 'Across all your books'
      : '${formatWords(widget.writtenToday)} of ${formatWords(widget.target!)} today, across all your books';

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DAILY TARGET', style: DsStyle.eyebrow()),
                const SizedBox(height: 4),
                Text(_acrossBooks, style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
              ],
            ),
          ),
          SizedBox(
            width: 96,
            child: GkField(
              controller: _controller,
              placeholder: '—',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              enabled: !_saving,
              onSubmitted: _commit,
            ),
          ),
        ],
      );
}
