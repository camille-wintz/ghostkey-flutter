import 'package:flutter/material.dart';

import '../../ui/text.dart';

/// One titled band of the entity page: an eyebrow, an optional action at the
/// right, then the content. No hairline — the space between bands separates
/// them.
class VeilSection extends StatelessWidget {
  const VeilSection({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Eyebrow(title)),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      );
}
