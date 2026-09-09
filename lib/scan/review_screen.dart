import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/words.dart';
import '../ds/tokens.dart';
import '../server/errors.dart';
import '../ui/button.dart';
import '../ui/press.dart';
import '../ui/state_screen.dart';
import 'fit_image.dart';
import 'ocr_run.dart';

/// The OCR result over the captured page, editable in the manuscript face
/// before it lands. Runs the OCR pass on mount; a plan refusal and every
/// other failure get their own face, worded by `messageFor`.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.image,
    required this.chapterTitle,
    required this.projectId,
    required this.onInsert,
    required this.onRetake,
    required this.onClose,
  });

  final EncodedImage image;
  final String chapterTitle;
  final String? projectId;
  final ValueChanged<String> onInsert;
  final VoidCallback onRetake;
  final VoidCallback onClose;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _ocr = OcrRun();
  final _edited = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ocr.addListener(_onOcr);
    _run();
  }

  @override
  void dispose() {
    _ocr.removeListener(_onOcr);
    _ocr.dispose();
    _edited.dispose();
    super.dispose();
  }

  void _run() => _ocr.run(widget.image, projectId: widget.projectId);

  void _onOcr() {
    if (!mounted) return;
    final text = _ocr.text;
    if (text != null && _edited.text != text) _edited.text = text;
    setState(() {});
  }

  void _insert() {
    final text = _edited.text.trim();
    if (text.isNotEmpty) widget.onInsert(text);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      color: Ds.void_,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onClose: widget.onClose),
            _Status(image: widget.image, ocr: _ocr, edited: _edited),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: Ds.panel,
                  border: Border.all(color: Ds.edge),
                  borderRadius: BorderRadius.circular(DsGeom.radius),
                ),
                child: _body(),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(18, 14, 18, math.max(bottomInset, keyboard) + 18),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Ds.edge))),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _edited,
                builder: (context, value, _) {
                  final empty = value.text.trim().isEmpty;
                  return Row(
                    children: [
                      _Retake(onPressed: widget.onRetake),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GkButton(
                          label: 'Insert into ${widget.chapterTitle}',
                          wide: true,
                          disabled: _ocr.busy || _ocr.error != null || empty,
                          onPressed: _insert,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_ocr.busy) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent),
        ),
      );
    }
    final error = _ocr.error;
    if (error != null) return _failure(error);

    return TextField(
      controller: _edited,
      maxLines: null,
      expands: true,
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.top,
      cursorColor: Ds.accent,
      style: TextStyle(
        fontFamily: DsFonts.manuscript,
        fontSize: DsText.prose.size,
        height: DsText.prose.height,
        color: Ds.ink,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(16),
        hintText: 'No text found. Retake the photo.',
        hintStyle: TextStyle(
          fontFamily: DsFonts.manuscript,
          fontSize: DsText.prose.size,
          height: DsText.prose.height,
          color: Ds.faint,
        ),
      ),
    );
  }

  /// A plan refusal is not retryable, so its face has one way out; anything
  /// else offers the pass again and the camera.
  Widget _failure(Object error) {
    final denied = error is ServerError && error.code == 'plan_insufficient';
    if (denied) {
      return StateScreen(
        icon: LucideIcons.lock,
        message: messageFor(error),
        actionLabel: 'Back to chapter',
        onAction: widget.onClose,
      );
    }
    return StateScreen(
      message: 'Could not read the page.',
      detail: messageFor(error),
      actionLabel: 'Try again',
      onAction: _run,
      secondaryActionLabel: 'Retake',
      onSecondaryAction: widget.onRetake,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Press(
            onPressed: onClose,
            semanticLabel: 'Cancel scan',
            builder: (context, pressed) => Opacity(
              opacity: pressed ? 0.6 : 1,
              child: SizedBox(width: 40, height: 40, child: Icon(LucideIcons.x, size: 21, color: Ds.soft)),
            ),
          ),
          Expanded(
            child: Text(
              'Review scan',
              textAlign: TextAlign.center,
              style: DsStyle.ui(DsText.ui, color: Ds.hi, tracking: DsTracking.control),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// The page's thumbnail beside where the pass stands: extracting, read (with
/// the word count as edited), or failed.
class _Status extends StatelessWidget {
  const _Status({required this.image, required this.ocr, required this.edited});
  final EncodedImage image;
  final OcrRun ocr;
  final TextEditingController edited;

  @override
  Widget build(BuildContext context) {
    final error = ocr.error;
    final headline = ocr.busy ? 'Extracting text…' : (error != null ? 'Could not read' : 'Text extracted');
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.rotate(
            angle: -1.5 * math.pi / 180,
            child: Container(
              width: 78,
              height: 100,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: Ds.surf,
                border: Border.all(color: Ds.edge),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Image.memory(image.bytes, fit: BoxFit.cover, gaplessPlayback: true),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.sparkles, size: 15, color: Ds.accent),
                      const SizedBox(width: 7),
                      Text(headline, style: DsStyle.ui(DsText.ui, color: Ds.accent)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: edited,
                    builder: (context, value, _) {
                      final line = error != null
                          ? messageFor(error)
                          : ocr.busy
                              ? 'Reading the page with Claude…'
                              : '${countWords(value.text)} words · edit any line before inserting.';
                      return Text(line, style: DsStyle.ui(DsText.eyebrow, color: Ds.mid));
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Retake extends StatelessWidget {
  const _Retake({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: 'Retake photo',
        builder: (context, pressed) => AnimatedContainer(
          duration: DsMotion.duration,
          width: 52,
          height: 44,
          decoration: BoxDecoration(
            color: pressed ? Ds.surf : Ds.raise,
            border: Border.all(color: pressed ? Ds.edgeHi : Ds.edge),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Icon(LucideIcons.rotateCcw, size: 20, color: Ds.mid),
        ),
      );
}
