import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/button.dart';
import '../../ui/notice_modal.dart';
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
                GkButton(label: 'Delete', variant: ButtonVariant.destructive, onPressed: () => Navigator.of(context).pop(true)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}
