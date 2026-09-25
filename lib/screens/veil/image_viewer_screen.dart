import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/picture_page.dart';
import '../../ui/press.dart';
import '../../veil/providers.dart';

/// A card's gallery at full size, one picture per page, opened on the one
/// tapped. Swiping moves between pictures until one is zoomed in; then the
/// pan is the picture's.
class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({super.key, required this.images, required this.seriesId, this.initialIndex = 0});
  final List<EntityImage> images;
  final String? seriesId;
  final int initialIndex;

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

  @override
  Widget build(BuildContext context) {
    final count = widget.images.length;
    return Scaffold(
      backgroundColor: Ds.void_,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: DsGeom.row + 8,
              child: Row(
                children: [
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
