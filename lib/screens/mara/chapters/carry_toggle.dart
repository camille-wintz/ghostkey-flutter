import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';
import '../../../mara/proposal.dart';
import '../../../ui/press.dart';

/// One question for the whole list: do the new chapters open on the words
/// that already exist, or on blank pages?
class CarryToggle extends StatelessWidget {
  const CarryToggle({super.key, required this.carry, required this.onToggle});
  final CarryState carry;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: carry.applies ? onToggle : null,
        semanticLabel: 'Start chapters from their existing text, ${carry.hint}',
        builder: (context, pressed) => Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: carry.mixed ? null : carry.checked,
                tristate: true,
                onChanged: carry.applies ? (_) => onToggle() : null,
                activeColor: Ds.accent,
                side: BorderSide(color: Ds.edgeHi),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Start chapters from their existing text',
                      style: DsStyle.ui(DsText.ui, color: carry.applies ? Ds.soft : Ds.faint),
                    ),
                    TextSpan(text: ' — ${carry.hint}', style: DsStyle.ui(DsText.ui, color: Ds.faint)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
