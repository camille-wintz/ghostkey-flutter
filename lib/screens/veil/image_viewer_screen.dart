import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/menu_sheet.dart';
import '../../ui/picture_page.dart';
import '../../ui/press.dart';
import '../../veil/providers.dart';

/// A card's gallery at full size, one picture per page, opened on the one
/// tapped. Swiping moves between pictures until one is zoomed in; then the
/// pan is the picture's. Opened from a card being edited, a ⋯ offers the
/// picture's two card actions; either closes the viewer once it lands,
/// since the pictures it was handed are the card as it was.
class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.images,
    required this.seriesId,
    this.initialIndex = 0,
    this.onSetPortrait,
    this.onRemove,
  });
  final List<EntityImage> images;
  final String? seriesId;
  final int initialIndex;
  final Future<void> Function(EntityImage image)? onSetPortrait;
  final Future<void> Function(EntityImage image)? onRemove;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _more() async {
    final image = widget.images[_index];
    final onSetPortrait = widget.onSetPortrait;
    final onRemove = widget.onRemove;
    final title = image.title.trim();
    final action = await showMenuSheet<Future<void> Function(EntityImage)>(
      context,
      title: title.isEmpty ? 'Picture' : title,
      entries: [
        if (onSetPortrait != null) MenuEntry(icon: LucideIcons.userRound, label: 'Set as portrait', value: onSetPortrait),
        if (onRemove != null)
          MenuEntry(icon: LucideIcons.imageMinus, label: 'Remove from this card', value: onRemove, destructive: true),
      ],
    );
    if (action == null || !mounted) return;
    final navigator = Navigator.of(context);
    await action(image);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.images.length;
    final hasActions = widget.onSetPortrait != null || widget.onRemove != null;
    return Scaffold(
      backgroundColor: Ds.void_,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: DsGeom.row + 8,
              child: Row(
                children: [
                  if (hasActions)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Press(
                        onPressed: _more,
                        semanticLabel: 'Picture actions',
                        builder: (context, pressed) => Container(
                          width: DsGeom.row,
                          height: DsGeom.row,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: pressed ? Ds.veil : const Color(0x00000000),
                            borderRadius: BorderRadius.circular(DsGeom.radius),
                          ),
                          child: Icon(LucideIcons.ellipsis, size: 22, color: Ds.hi),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: DsGeom.row + 12),
                  Expanded(
                    child: count > 1
                        ? Text(
                            '${_index + 1} of $count',
                            textAlign: TextAlign.center,
                            style: DsStyle.ui(DsText.ui, color: Ds.mid),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Press(
                      onPressed: () => Navigator.of(context).pop(),
                      semanticLabel: 'Close',
                      builder: (context, pressed) => Container(
                        width: DsGeom.row,
                        height: DsGeom.row,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: pressed ? Ds.veil : const Color(0x00000000),
                          borderRadius: BorderRadius.circular(DsGeom.radius),
                        ),
                        child: Icon(LucideIcons.x, size: 22, color: Ds.hi),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                itemCount: count,
                onPageChanged: (i) => setState(() {
                  _index = i;
                  _zoomed = false;
                }),
                itemBuilder: (context, i) {
                  final image = widget.images[i];
                  final url = seriesAssetUrl(widget.seriesId, image.assetId);
                  if (url == null) return const SizedBox.shrink();
                  return PicturePage(
                    key: ValueKey(image.id),
                    url: url,
                    title: image.title,
                    caption: image.caption,
                    onZoomed: (zoomed) => setState(() => _zoomed = zoomed),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
