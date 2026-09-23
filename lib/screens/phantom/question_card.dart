import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/questions.dart';
import '../../ds/tokens.dart';
import '../../server/dto/chat.dart';
import '../../ui/button.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';

/// The questions a turn stopped on, beneath its answer. Live on the last
/// message while nothing is in flight (`onAnswer` set): one pick per
/// question, and "Send answers" sends the picks as the author's next message.
/// Anywhere else it is the record of what was asked — read-only, muted.
class QuestionCard extends StatefulWidget {
  const QuestionCard({super.key, required this.questions, this.onAnswer});
  final List<ChatQuestion> questions;

  /// Sends a user message through the composer's path. Null = read-only.
  final ValueChanged<String>? onAnswer;

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  QuestionChoices _choices = const QuestionChoices();

  @override
  Widget build(BuildContext context) {
    final onAnswer = widget.onAnswer;
    final live = onAnswer != null;
    final questions = widget.questions;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var q = 0; q < questions.length; q++)
            Padding(
              padding: EdgeInsets.only(top: q == 0 ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  UiText('${q + 1}. ${questions[q].question}', color: live ? Ds.hi : Ds.mid, weight: FontWeight.w600),
                  for (final option in questions[q].options)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _OptionRow(
                        option: option,
                        picked: _choices[q] == option,
                        onPressed: live ? () => setState(() => _choices = _choices.toggle(q, option)) : null,
                      ),
                    ),
                ],
              ),
            ),
          if (live) ...[
            const SizedBox(height: 12),
            UiText('Or answer in your own words below.', step: DsText.ui, color: Ds.low),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: GkButton(
                label: 'Send answers',
                disabled: _choices.isEmpty,
                onPressed: () => onAnswer(answersMessage(questions, _choices)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One suggested answer: a full-width row, since an option can be a whole
/// sentence. Inert (and muted) when `onPressed` is null.
class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.picked, required this.onPressed});
  final String option;
  final bool picked;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    if (onPressed == null) return _box(pressed: false, live: false);
    return Semantics(
      selected: picked,
      child: Press(
        onPressed: onPressed,
        semanticLabel: option,
        builder: (context, pressed) => _box(pressed: pressed, live: true),
      ),
    );
  }

  Widget _box({required bool pressed, required bool live}) => AnimatedContainer(
        duration: DsMotion.duration,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: picked ? Ds.accentMix(14) : (pressed ? Ds.accentMix(8) : Ds.panel),
          border: Border.all(color: picked ? Ds.accentMix(55) : (pressed ? Ds.edgeHi : Ds.edge)),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: UiText(option, step: DsText.ui, color: !live ? Ds.low : (picked ? Ds.hi : Ds.soft)),
            ),
            if (picked) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(LucideIcons.check, size: 14, color: Ds.accent),
              ),
            ],
          ],
        ),
      );
}
