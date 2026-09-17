import 'package:flutter/material.dart';

import '../ds/tokens.dart';

/// A title bar's subtitle as plain text, uppercased the way the eyebrow is.
class RoomSubtitle extends StatelessWidget {
  const RoomSubtitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: DsStyle.eyebrow().copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      );
}
