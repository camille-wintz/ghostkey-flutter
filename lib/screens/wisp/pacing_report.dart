import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/chapter_title.dart';
import '../../core/words.dart';
import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';
import 'pacing_wave.dart';
import 'report_card.dart';

/// The wave, then the book — or the chapters picked — read for engagement,
/// then each act, folded, read the same way.
class PacingReport extends StatelessWidget {
  const PacingReport({super.key, required this.report});
  final AnalysisReport report;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (report.beats.isNotEmpty) ...[PacingWave(beats: report.beats), const SizedBox(height: 18)],
          Text(report.ranged ? 'THESE CHAPTERS' : 'THE BOOK', style: DsStyle.eyebrow()),
          const SizedBox(height: 10),
          ReportCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report.overview.isNotEmpty) ...[
                  Text(report.overview, style: DsStyle.prose(DsText.body, color: Ds.soft)),
                  const SizedBox(height: 4),
                ],
                _Reading(reading: report.reading),
              ],
            ),
          ),
          if (report.acts.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text('THE ACTS', style: DsStyle.eyebrow()),
            const SizedBox(height: 10),
            for (final (i, a) in report.acts.indexed) _ActCard(index: i, act: a),
          ],
        ],
      );
}

/// Hue is state, as on the genre chips: what works is done, what is worth a
/// look is attention, the middle carries no hue.
(String, Color) _pace(PacingPace pace) => switch (pace) {
      PacingPace.quick => ('Quick', Ds.done),
      PacingPace.steady => ('Steady', Ds.low),
      PacingPace.slow => ('Slow', Ds.attention),
    };

(String, Color) _connection(PacingConnection c) => switch (c) {
      PacingConnection.tight => ('Tight', Ds.done),
      PacingConnection.partial => ('Partly tied', Ds.low),
      PacingConnection.loose => ('Loose', Ds.attention),
    };

/// "Chapter 3 · 8 400 words in (12%)" — with only what the report could count.
String _where(PacingMilestone m) {
  final wordsIn = m.wordsIn;
  if (wordsIn == null) return chapterLabel(m.chapter);
  final share = m.share == null ? '' : ' (${(m.share! * 100).round()}%)';
  return '${chapterLabel(m.chapter)} · ${formatWords(wordsIn)} words in$share';
}

/// The three questions, then the tips — the same for the book and each act.
class _Reading extends StatelessWidget {
  const _Reading({required this.reading});
  final PacingReading reading;

  @override
  Widget build(BuildContext context) {
    final hook = reading.hook;
    final rise = reading.rise;
    final resolution = reading.resolution;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hook != null) _Milestone(title: 'Engaging the reader', milestone: hook, divider: false),
        if (rise != null) _Milestone(title: 'Tension rising', milestone: rise, divider: hook != null),
        if (resolution != null)
          _Question(
            title: 'The resolution',
            verdict: _connection(resolution.connection),
            divider: hook != null || rise != null,
            children: [
              if (resolution.reading.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(resolution.reading, style: DsStyle.prose(DsText.body, color: Ds.soft)),
              ],
              if (resolution.looseEnds.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Left hanging', style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
                for (final t in resolution.looseEnds)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('– $t', style: DsStyle.prose(DsText.body, color: Ds.mid)),
                  ),
              ],
            ],
          ),
        if (reading.tips.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: Ds.accent, width: 2))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Keeping the reader engaged', style: DsStyle.ui(DsText.ui, color: Ds.ink, weight: FontWeight.w600)),
                for (final t in reading.tips)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(t, style: DsStyle.prose(DsText.body, color: Ds.soft)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Milestone extends StatelessWidget {
  const _Milestone({required this.title, required this.milestone, required this.divider});
  final String title;
  final PacingMilestone milestone;
  final bool divider;

  @override
  Widget build(BuildContext context) => _Question(
        title: title,
        verdict: _pace(milestone.pace),
        where: _where(milestone),
        divider: divider,
        children: [
          if (milestone.reading.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(milestone.reading, style: DsStyle.prose(DsText.body, color: Ds.soft)),
          ],
        ],
      );
}

class _Question extends StatelessWidget {
  const _Question({required this.title, required this.verdict, this.where, required this.divider, required this.children});
  final String title;
  final (String, Color) verdict;
  final String? where;
  final bool divider;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: divider ? BoxDecoration(border: Border(top: BorderSide(color: Ds.edge))) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(title, style: DsStyle.ui(DsText.ui, color: Ds.ink, weight: FontWeight.w600))),
                const SizedBox(width: 12),
                _Chip(label: verdict.$1, color: verdict.$2),
              ],
            ),
            if (where != null) ...[
              const SizedBox(height: 2),
              Text(where!, style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
            ],
            ...children,
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, this.prefix});
  final String label;
  final Color color;
  final String? prefix;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Text.rich(
          TextSpan(children: [
            if (prefix != null) TextSpan(text: '$prefix ', style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
            TextSpan(text: label, style: DsStyle.ui(DsText.eyebrow, color: color)),
          ]),
        ),
      );
}

/// One act, folded to its name, chapters and three verdicts; opens onto the
/// same reading as the book.
class _ActCard extends StatefulWidget {
  const _ActCard({required this.index, required this.act});
  final int index;
  final PacingAct act;

  @override
  State<_ActCard> createState() => _ActCardState();
}

class _ActCardState extends State<_ActCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final act = widget.act;
    final r = act.reading;
    final verdicts = [
      if (r.hook != null) ('Hook', _pace(r.hook!.pace)),
      if (r.rise != null) ('Rise', _pace(r.rise!.pace)),
      if (r.resolution != null) ('Ending', _connection(r.resolution!.connection)),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ReportCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              borderRadius: BorderRadius.circular(DsGeom.radius),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${widget.index + 1}. ${act.name}', style: DsStyle.prose(const DsStep(18, 24), color: Ds.hi)),
                          const SizedBox(height: 2),
                          Text(
                            act.from == act.to ? chapterLabel(act.from) : '${chapterLabel(act.from)} → ${chapterLabel(act.to)}',
                            style: DsStyle.ui(DsText.eyebrow, color: Ds.low),
                          ),
                          if (verdicts.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final (prefix, (label, color)) in verdicts)
                                  _Chip(label: label, color: color, prefix: prefix),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(LucideIcons.chevronDown, size: 18, color: Ds.low),
                    ),
                  ],
                ),
              ),
            ),
            if (_open)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Ds.edge))),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (act.summary.isNotEmpty) Text(act.summary, style: DsStyle.prose(DsText.body, color: Ds.soft)),
                    _Reading(reading: r),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
