import 'package:flutter/material.dart';

import '../ds/tokens.dart';
import 'button.dart';
import 'sheet.dart';

/// Ask once before something that cannot be taken back from here. A sheet
/// rather than a dialog: the page stays visible behind it, which is where the
/// question came from. Resolves true only on the confirm button.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String eyebrow,
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final answer = await showGkSheet<bool>(
    context,
    header: SheetHeader(eyebrow: eyebrow, onClose: () => Navigator.of(context).pop()),
    builder: (sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: DsStyle.prose(DsText.title, weight: FontWeight.w600)),
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(message, style: DsStyle.ui(DsText.body, color: Ds.mid)),
          ],
          const SizedBox(height: 20),
          GkButton(
            label: confirmLabel,
            variant: destructive ? ButtonVariant.destructive : ButtonVariant.primary,
            wide: true,
            onPressed: () => Navigator.of(sheet).pop(true),
          ),
          const SizedBox(height: 10),
          GkButton(label: cancelLabel, variant: ButtonVariant.outline, wide: true, onPressed: () => Navigator.of(sheet).pop(false)),
        ],
      ),
    ),
  );
  return answer ?? false;
}
