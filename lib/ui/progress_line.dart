import 'package:flutter/material.dart';

import '../ds/tokens.dart';

/// A run going on the server, as one line above a page: a small light and
/// what the run says it is doing.
class ProgressLine extends StatelessWidget {
  const ProgressLine(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Row(
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent)),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: DsStyle.ui(DsText.ui, color: Ds.accent300))),
          ],
        ),
      );
}
