import 'package:flutter/widgets.dart';

import '../../ds/tokens.dart';
import '../../ui/text.dart';

/// Past this many messages the thread says so, once, above the composer.
const int longThread = 20;

/// Past 20 messages a thread costs more than it gives back. One line of copy
/// above the composer, no dismissal, no state — by decision.
class LongThreadNote extends StatelessWidget {
  const LongThreadNote({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
        child: UiText(
          'Long conversations cost more and remember less — start a new chat for a new question.',
          step: DsText.ui,
          color: Ds.faint,
        ),
      );
}
