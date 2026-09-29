import 'package:flutter/material.dart';

import '../../ds/tokens.dart';

/// A passage from the book, set in from the reader's words.
class QuotedPassage extends StatelessWidget {
  const QuotedPassage(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8, left: 4),
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: Ds.edgeHi, width: 2))),
        child: Text(
          text,
          style: DsStyle.prose(DsText.body, color: Ds.mid).copyWith(fontStyle: FontStyle.italic),
        ),
      );
}
