import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/button.dart';
import '../../ui/room_back_button.dart';
import '../../ui/text.dart';

/// The top row of a card's full-screen editor: back to the card, what is
/// being written and whose it is, and Save. The phone web's
/// `EditorScreenHeader.tsx` is the same row.
class EditorScreenHeader extends StatelessWidget {
  const EditorScreenHeader({
    super.key,
    required this.eyebrow,
    required this.name,
    required this.onBack,
    required this.onSave,
    required this.saving,
    this.canSave = true,
  });

  final String eyebrow;
  final String name;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final bool saving;
  final bool canSave;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 16, 4),
        child: Row(
          children: [
            RoomBackButton(onPressed: onBack, semanticLabel: 'Back to the card'),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(eyebrow),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsStyle.prose(DsText.body, color: Ds.hi),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GkButton(label: 'Save', busy: saving, disabled: !canSave, onPressed: onSave),
          ],
        ),
      );
}
