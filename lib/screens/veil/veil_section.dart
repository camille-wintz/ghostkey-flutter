import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/text.dart';

/// One titled band of the entity page: an eyebrow over a hairline, an
/// optional action at the right, then the content.
class VeilSection extends StatelessWidget {
  const VeilSection({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: Eyebrow(title)),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      );
}
