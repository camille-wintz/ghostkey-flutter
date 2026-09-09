import 'package:flutter/material.dart';

import 'fit_image.dart';
import 'review_screen.dart';
import 'viewfinder_screen.dart';

/// The scan flow as one pushed screen with two steps: the viewfinder, then
/// the review over what it captured. Pops with the reviewed text on
/// "Insert", with nothing on a close. Android's back walks the steps in
/// reverse — from the review it is a retake, not an exit — and the camera
/// is released while the review is up, so the upload never holds it.
class ScanRoute extends StatefulWidget {
  const ScanRoute({super.key, required this.chapterTitle, required this.projectId});
  final String chapterTitle;
  final String? projectId;

  @override
  State<ScanRoute> createState() => _ScanRouteState();
}

class _ScanRouteState extends State<ScanRoute> {
  EncodedImage? _captured;

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final captured = _captured;
    return PopScope(
      canPop: captured == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _captured = null);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        resizeToAvoidBottomInset: false,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          child: captured == null
              ? ViewfinderScreen(
                  key: const ValueKey('viewfinder'),
                  onCaptured: (image) => setState(() => _captured = image),
                  onClose: _close,
                )
              : ReviewScreen(
                  key: const ValueKey('review'),
                  image: captured,
                  chapterTitle: widget.chapterTitle,
                  projectId: widget.projectId,
                  onInsert: (text) => Navigator.of(context).pop(text),
                  onRetake: () => setState(() => _captured = null),
                  onClose: _close,
                ),
        ),
      ),
    );
  }
}
