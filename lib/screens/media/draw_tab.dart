import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../media/draw_run.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/page_notice.dart';
import 'draw_size_switch.dart';

/// The Draw tab: the prompt, the size, and under them the one verb. The run
/// is the picker's [DrawRun], not this tab's, so the author can go to the
/// library while it draws and come back to it.
class DrawTab extends StatelessWidget {
  const DrawTab({super.key, required this.run, required this.onDraw, required this.locked, this.quota});
  final DrawRun run;
  final VoidCallback onDraw;

  /// Not on the plan: the button stays, padlocked, and explains on a tap.
  final bool locked;

  /// "1 of 10 drawings left this week", or null when unlimited or unknown.
  final String? quota;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: run,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 24 + MediaQuery.paddingOf(context).bottom),
          children: [
            Row(
              children: [
                Text('DRAW A PICTURE', style: DsStyle.eyebrow()),
                const Spacer(),
                if (run.busy) ...[
                  SizedBox.square(dimension: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Ds.accent)),
                  const SizedBox(width: 8),
                  Text('Drawing…', style: DsStyle.ui(DsText.ui, color: Ds.mid)),
                ],
              ],
            ),
            const SizedBox(height: 10),
            GkField(
              controller: run.prompt,
              placeholder: 'A tall, slender young man in a dark coat, gaslight behind him…',
              minLines: 5,
              maxLines: 10,
              maxLength: 4000,
              enabled: !run.busy,
            ),
            const SizedBox(height: 14),
            DrawSizeSwitch(value: run.size, onChanged: run.setSize, enabled: !run.busy),
            const SizedBox(height: 16),
            GkButton(
              label: run.hasDrawn ? 'Draw again' : 'Draw',
              wide: true,
              busy: run.busy,
              disabled: run.prompt.text.trim().isEmpty,
              leading: Icon(locked ? LucideIcons.lock : LucideIcons.sparkles, size: 15, color: Ds.accent),
              onPressed: onDraw,
            ),
            if (quota case final quota?) ...[
              const SizedBox(height: 8),
              Text(quota, textAlign: TextAlign.center, style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
            ],
            if (run.busy) ...[
              const SizedBox(height: 14),
              Text(
                'A picture takes a minute or two. You can look through the library meanwhile.',
                textAlign: TextAlign.center,
                style: DsStyle.ui(DsText.ui, color: Ds.low),
              ),
            ],
            if (run.error case final error? when !run.busy) ...[
              const SizedBox(height: 14),
              PageNotice(error, error: true),
            ],
          ],
        ),
      );
}
