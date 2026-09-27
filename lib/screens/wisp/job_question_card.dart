import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/jobs.dart';
import '../../server/errors.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';

/// Answers [question] with the picked option and the typed text (trimmed,
/// null when the option has no input). Throws to show the card's error line.
typedef QuestionAnswer = Future<void> Function(JobQuestionOption option, String? text);

/// One question a continuity run asks — "which is the story?". An option
/// with an input opens a free-text field first; the text is what teaches the
/// agent. Where the answer goes is the caller's: the job feed's row, or the
/// report's finding. Answered, the caller's refetch drops the question and
/// the card with it.
class JobQuestionCard extends StatefulWidget {
  const JobQuestionCard({super.key, required this.question, required this.onAnswer});
  final JobQuestion question;
  final QuestionAnswer onAnswer;

  @override
  State<JobQuestionCard> createState() => _JobQuestionCardState();
}

class _JobQuestionCardState extends State<JobQuestionCard> {
  final _text = TextEditingController();
  JobQuestionOption? _inputFor;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit(JobQuestionOption option, {String? text}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onAnswer(option, text?.trim());
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't save that answer (${messageFor(e)}) — try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final input = _inputFor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Ds.accentMix(5),
        border: Border.all(color: Ds.accent.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(LucideIcons.circleHelp, size: 15, color: Ds.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.question, style: DsStyle.ui(DsText.ui, color: Ds.soft)),
                    if (q.detail case final detail? when detail.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(detail, style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (input == null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in q.options)
                  GkButton(
                    label: option.label,
                    variant: ButtonVariant.outline,
                    disabled: _busy,
                    onPressed: () => option.inputPlaceholder != null
                        ? setState(() => _inputFor = option)
                        : _submit(option),
                  ),
              ],
            )
          else ...[
            GkField(
              controller: _text,
              placeholder: input.inputPlaceholder,
              autofocus: true,
              enabled: !_busy,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) => _submit(input, text: value),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GkButton(
                  label: 'Back',
                  variant: ButtonVariant.outline,
                  disabled: _busy,
                  onPressed: () => setState(() => _inputFor = null),
                ),
                const SizedBox(width: 8),
                GkButton(label: input.label, busy: _busy, onPressed: () => _submit(input, text: _text.text)),
              ],
            ),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: 8),
            Text(error, style: DsStyle.ui(DsText.eyebrow, color: Ds.destructive)),
          ],
        ],
      ),
    );
  }
}
