import 'package:flutter/material.dart';

import '../../ds/tokens.dart';

/// A labelled paragraph inside a report card. Nothing at all when there is
/// nothing to say, so an empty field leaves no empty label.
class ReportSection extends StatelessWidget {
  const ReportSection({super.key, required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DsStyle.ui(DsText.ui, color: Ds.ink, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(text, style: DsStyle.prose(DsText.body, color: Ds.soft)),
        ],
      ),
    );
  }
}
