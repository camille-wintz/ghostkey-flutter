import 'package:flutter/material.dart';

import '../../chat/live_answer.dart';
import '../../ds/tokens.dart';
import '../../server/dto/chat.dart';
import '../../ui/text.dart';
import 'chat_markdown.dart';
import 'pulse.dart';
import 'recall_rail.dart';

/// The answer being written: the live recall rail, then "Recalling…"
/// pulsing until the first word, then the streamed markdown.
///
/// Listens to the answer's two ValueNotifiers directly, so a frame rebuilds
/// this widget and nothing above it — the stream-to-paint budget (P9) is
/// spent here alone.
class PendingTurnView extends StatelessWidget {
  const PendingTurnView({super.key, required this.live});
  final LiveAnswer live;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: ValueListenableBuilder<List<ChatToolStep>>(
          valueListenable: live.steps,
          builder: (context, steps, _) {
            final recalling = steps.any((s) => s.status == ChatToolStepStatus.running);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                RecallRail(steps: steps, live: true),
                ValueListenableBuilder<String>(
                  valueListenable: live.text,
                  builder: (context, text, _) {
                    if (text.isEmpty) {
                      return Pulse(
                        active: true,
                        child: UiText(recalling ? 'Recalling…' : 'Thinking…', step: DsText.ui, color: Ds.mid),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ChatMarkdown(text),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: UiText('writing…', step: DsText.eyebrow, color: Ds.faint),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      );
}
