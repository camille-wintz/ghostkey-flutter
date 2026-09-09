import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/button.dart';
import '../../ui/notice_modal.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';

/// "Delete this chat?" — resolves true when the author confirms.
Future<bool> confirmDeleteChat(BuildContext context, {required String title}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xC708060D),
    builder: (context) => Dialog(
      backgroundColor: const Color(0x00000000),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Ds.panel,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandTitle('Delete this chat?', size: BrandTitleSize.chrome),
            const SizedBox(height: 10),
            NoticeText('“$title” cannot be recovered.'),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GkButton(label: 'Cancel', variant: ButtonVariant.outline, onPressed: () => Navigator.of(context).pop(false)),
                const SizedBox(width: 8),
                _DestructiveButton(label: 'Delete', onPressed: () => Navigator.of(context).pop(true)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}

/// GkButton's geometry in the destructive hue. The house button has no
/// destructive variant yet; when one lands in ui/button.dart this goes.
class _DestructiveButton extends StatelessWidget {
  const _DestructiveButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: label,
        builder: (context, pressed) => AnimatedContainer(
          duration: DsMotion.duration,
          height: DsGeom.ctl,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DsGeom.radius),
            border: Border.all(color: Ds.destructive.withValues(alpha: pressed ? 1 : 0.55)),
            color: Ds.destructive.withValues(alpha: pressed ? 0.2 : 0.12),
          ),
          child: Text(
            label.toUpperCase(),
            style: DsStyle.ui(DsText.ui, color: Ds.destructive, weight: FontWeight.w600, tracking: DsTracking.control),
          ),
        ),
      );
}
