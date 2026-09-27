import 'package:flutter/material.dart';

import '../../ui/confirm_sheet.dart';

/// Leaving a card's full-screen editor, by its back arrow or the phone's:
/// straight out when nothing changed, after a confirm when something did,
/// never mid-save. The phone web's `useLeaveGuard`. The editor's back arrow
/// asks the route (`maybePop`) so both ways out land here; its Save pops
/// past it.
class EditorLeaveGuard extends StatelessWidget {
  const EditorLeaveGuard({
    super.key,
    required this.dirty,
    required this.saving,
    required this.eyebrow,
    required this.message,
    required this.child,
  });

  final bool dirty;
  final bool saving;

  /// The confirm sheet's eyebrow: what is being written.
  final String eyebrow;

  /// What will be lost.
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !dirty && !saving,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop || saving) return;
          final discard = await showConfirmSheet(
            context,
            eyebrow: eyebrow,
            title: 'Discard your changes?',
            message: message,
            confirmLabel: 'Discard',
            destructive: true,
          );
          if (discard && context.mounted) Navigator.of(context).pop();
        },
        child: child,
      );
}
