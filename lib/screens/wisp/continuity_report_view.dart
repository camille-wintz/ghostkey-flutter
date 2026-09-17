import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';
import 'finding_card.dart';
import 'report_card.dart';

/// The finished report: hard errors first, then arc-drift craft notes — two
/// visibly separate sections so the error list stays trustworthy.
class ContinuityReportView extends StatelessWidget {
  const ContinuityReportView({super.key, required this.report});
  final ContinuityReport report;

  @override
  Widget build(BuildContext context) {
    final candidates = report.candidates;
    if (report.hardErrors.isEmpty && report.arcDrift.isEmpty) {
      // Celebratory on purpose: zero findings is the expected outcome for a
      // consistent manuscript, and should read as trustworthy, not as a
      // failed scan.
      return ReportCard(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Ds.done.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(DsGeom.radius),
              ),
              child: Icon(LucideIcons.circleCheck, size: 22, color: Ds.done),
            ),
            const SizedBox(height: 14),
            Text(
              'No continuity errors found',
              style: DsStyle.ui(DsText.body, color: Ds.hi, weight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '${report.chaptersAnalyzed} chapters analyzed, ${report.claimsExtracted} claims checked'
              '${candidates > 0 ? ', $candidates candidate${candidates == 1 ? '' : 's'} dismissed on verification' : ''}'
              '. A clean report is the expected outcome for a consistent manuscript.',
              textAlign: TextAlign.center,
              style: DsStyle.ui(DsText.ui, color: Ds.mid),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          heading: 'Hard continuity errors',
          note:
              'Contradictions of established facts, timeline, knowledge, geography, world rules, or possessions — each survived an adversarial verification pass.',
          findings: report.hardErrors,
        ),
        const SizedBox(height: 26),
        _Section(
          heading: 'Arc-drift notes',
          note: 'Craft observations — places where the page may not deliver the outlined character arc. Not errors.',
          findings: report.arcDrift,
        ),
        const SizedBox(height: 18),
        Text(
          '${report.chaptersAnalyzed} chapters analyzed · ${report.claimsExtracted} claims checked · '
          '$candidates candidates, ${report.dismissed} dismissed on verification',
          style: DsStyle.ui(DsText.eyebrow, color: Ds.faint),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.heading, required this.note, required this.findings});
  final String heading;
  final String note;
  final List<ContinuityFinding> findings;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(heading, style: DsStyle.ui(DsText.body, color: Ds.hi, weight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text('${findings.length}', style: DsStyle.ui(DsText.ui, color: Ds.low)),
            ],
          ),
          const SizedBox(height: 4),
          Text(note, style: DsStyle.ui(DsText.eyebrow, color: Ds.low).copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 12),
          if (findings.isEmpty)
            Text('None found.', style: DsStyle.ui(DsText.ui, color: Ds.low))
          else
            for (final finding in findings)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: FindingCard(finding: finding)),
        ],
      );
}
