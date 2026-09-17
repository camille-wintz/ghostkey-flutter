import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/chapter_title.dart';
import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';
import 'report_card.dart';

/// One finding: category, entity and chapters, the two verbatim quotes, and
/// the explanation. An unverified finding — kept after a failed verify call —
/// is badged so the author reads it with caution.
class FindingCard extends StatelessWidget {
  const FindingCard({super.key, required this.finding});
  final ContinuityFinding finding;

  static String _resolution(ContinuityResolution r) => switch (r.choice) {
        'prior' => 'Resolved — the earlier chapter is right',
        'current' => 'Resolved — the newer chapter is right',
        _ => 'Resolved — intentional change',
      };

  @override
  Widget build(BuildContext context) {
    final f = finding;
    final hue = f.hardError ? Ds.destructive : Ds.attention;
    final prior = f.priorChapter;
    final chapters = prior != null && prior != f.chapter
        ? '${chapterLabel(f.chapter)} ↔ ${chapterLabel(prior)}'
        : chapterLabel(f.chapter);

    return ReportCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Badge(label: f.category.replaceAll('_', ' '), color: hue),
              if (f.entity case final entity?) Text(entity, style: DsStyle.ui(DsText.eyebrow, color: Ds.soft)),
              Text(chapters, style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
            ],
          ),
          if (f.resolution != null || !f.verified) ...[
            const SizedBox(height: 8),
            if (f.resolution case final r?)
              _Badge(label: _resolution(r), color: Ds.done, icon: LucideIcons.check)
            else
              _Badge(label: 'Unverified — treat with caution', color: Ds.mid, icon: LucideIcons.triangleAlert),
          ],
          if (f.claim case final claim?) ...[
            const SizedBox(height: 10),
            Text(claim, style: DsStyle.ui(DsText.ui, color: Ds.hi, weight: FontWeight.w600)),
          ],
          if (f.quote case final quote?) _Quote(text: quote, source: chapterLabel(f.chapter)),
          if (f.priorQuote case final quote?) _Quote(text: quote, source: prior != null ? chapterLabel(prior) : 'earlier'),
          if (f.explanation case final explanation?) ...[
            const SizedBox(height: 10),
            Text(explanation, style: DsStyle.ui(DsText.ui, color: Ds.mid)),
          ],
          if (f.resolution?.note case final note? when note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('“$note”', style: DsStyle.ui(DsText.ui, color: Ds.mid).copyWith(fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 4)],
            Flexible(child: Text(label, style: DsStyle.ui(DsText.eyebrow, color: color, weight: FontWeight.w600))),
          ],
        ),
      );
}

class _Quote extends StatelessWidget {
  const _Quote({required this.text, required this.source});
  final String text;
  final String source;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: Ds.faint, width: 2))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('“$text”', style: DsStyle.prose(DsText.body, color: Ds.soft)),
            const SizedBox(height: 2),
            Text(source, style: DsStyle.ui(DsText.eyebrow, color: Ds.low).copyWith(fontStyle: FontStyle.italic)),
          ],
        ),
      );
}
