import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/jobs.dart';

/// A run in flight, in the page's place: what the job says it is doing, and
/// that leaving is safe.
class WispRunning extends StatelessWidget {
  const WispRunning({super.key, required this.progress, required this.starting, this.note});
  final JobProgress? progress;

  /// What to say before the job has said anything.
  final String starting;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final counter = p != null && !p.indeterminate && p.total > 1 ? ' ${p.current}/${p.total}' : '';
    final label = p != null && p.label.isNotEmpty ? '${p.label}…$counter' : '$starting…';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 12),
      child: Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Ds.accent),
          ),
          const SizedBox(height: 18),
          Text(label, textAlign: TextAlign.center, style: DsStyle.ui(DsText.ui, color: Ds.mid)),
          const SizedBox(height: 8),
          Text(
            note ?? 'You can leave this page — the result is kept.',
            textAlign: TextAlign.center,
            style: DsStyle.ui(DsText.eyebrow, color: Ds.low),
          ),
        ],
      ),
    );
  }
}
