import 'package:flutter/material.dart';

import '../ds/tokens.dart';

/// One picture filling the space it is given, pinch-zoomable, with its title
/// and caption beneath. The page a full-screen viewer swipes between and the
/// chat's Review of a picture both draw.
///
/// [onZoomed] reports whether the picture is zoomed in, so a pager can stop
/// taking the pan that should move the picture.
class PicturePage extends StatefulWidget {
  const PicturePage({super.key, required this.url, this.title = '', this.caption = '', this.onZoomed});
  final String url;
  final String title;
  final String caption;
  final ValueChanged<bool>? onZoomed;

  @override
  State<PicturePage> createState() => _PicturePageState();
}

class _PicturePageState extends State<PicturePage> {
  final _transform = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _settle() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomed?.call(zoomed);
  }

  void _reset() {
    _transform.value = Matrix4.identity();
    _settle();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title.trim();
    final caption = widget.caption.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GestureDetector(
            onDoubleTap: _reset,
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 1,
              maxScale: 5,
              onInteractionEnd: (_) => _settle(),
              child: Center(
                child: Image.network(
                  widget.url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Ds.low),
                        ),
                  errorBuilder: (context, _, _) =>
                      Text('This picture would not load', style: DsStyle.ui(DsText.ui, color: Ds.low)),
                ),
              ),
            ),
          ),
        ),
        if (title.isNotEmpty || caption.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.28),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty) Text(title, style: DsStyle.ui(DsText.body, color: Ds.hi, weight: FontWeight.w600)),
                  if (title.isNotEmpty && caption.isNotEmpty) const SizedBox(height: 4),
                  if (caption.isNotEmpty) Text(caption, style: DsStyle.ui(DsText.ui, color: Ds.mid)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
