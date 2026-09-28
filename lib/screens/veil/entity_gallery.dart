import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/hold_to_drag.dart';
import '../../ui/press.dart';
import '../../veil/gallery_order.dart';
import '../../veil/providers.dart';
import 'gallery_add_tile.dart';
import 'image_viewer_screen.dart';
import 'veil_section.dart';

/// The card's pictures as one strip above the dossier, each at its own
/// shape and one height. A tap opens the picture full size. While editing
/// ([onAdd] given) the strip ends in an Add tile, a hold lifts a picture to
/// drag it along the strip, and the full-size viewer offers the picture's
/// actions. Every picture is a library item on the card by reference.
class EntityGallery extends StatefulWidget {
  const EntityGallery({
    super.key,
    required this.images,
    required this.seriesId,
    this.onAdd,
    this.adding = false,
    this.onReorder,
    this.onSetPortrait,
    this.onRemove,
  });
  final List<EntityImage> images;
  final String? seriesId;

  final VoidCallback? onAdd;
  final bool adding;

  /// The whole strip's item ids in their new order.
  final Future<void> Function(List<String> itemIds)? onReorder;
  final Future<void> Function(EntityImage image)? onSetPortrait;
  final Future<void> Function(EntityImage image)? onRemove;

  static const double height = 120;

  @override
  State<EntityGallery> createState() => _EntityGalleryState();
}

class _EntityGalleryState extends State<EntityGallery> {
  /// The dropped order, drawn until the card's re-read brings the server's
  /// — so the picture doesn't jump back for the length of a request. Never
  /// written anywhere; the next [EntityGallery.images] replaces it.
  List<EntityImage>? _dropped;

  @override
  void didUpdateWidget(EntityGallery old) {
    super.didUpdateWidget(old);
    if (!identical(old.images, widget.images)) _dropped = null;
  }

  List<EntityImage> get _shown => _dropped ?? widget.images;

  void _open(int index) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => ImageViewerScreen(
            images: _shown,
            seriesId: widget.seriesId,
            initialIndex: index,
            onSetPortrait: widget.onSetPortrait,
            onRemove: widget.onRemove,
          ),
        ),
      );

  Future<void> _drop(int from, int to) async {
    final shown = _shown;
    final order = movedOrder([for (final i in shown) i.itemId], from, to);
    final byItem = {for (final i in shown) i.itemId: i};
    setState(() => _dropped = [for (final id in order) byItem[id]!]);
    try {
      await widget.onReorder?.call(order);
    } finally {
      // A refused order puts the strip back as the server has it.
      if (mounted) setState(() => _dropped = null);
    }
  }

  Widget _thumb(int i) {
    final image = _shown[i];
    return _Thumb(
      image: image,
      url: seriesAssetUrl(widget.seriesId, image.thumbAssetId),
      height: EntityGallery.height,
      onOpen: () => _open(i),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final onAdd = widget.onAdd;
    final editing = onAdd != null;
    return VeilSection(
      title: 'Gallery',
      child: SizedBox(
        height: EntityGallery.height,
        child: editing
            ? ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                buildDefaultDragHandles: false,
                itemCount: shown.length,
                proxyDecorator: (child, index, animation) => child,
                onReorderStart: (_) => HapticFeedback.selectionClick(),
                onReorderItem: _drop,
                footer: GalleryAddTile(height: EntityGallery.height, onPressed: onAdd, busy: widget.adding),
                itemBuilder: (context, i) => HoldToDrag(
                  key: ValueKey(shown[i].id),
                  index: i,
                  enabled: widget.onReorder != null && shown.length > 1,
                  child: Padding(padding: const EdgeInsets.only(right: 8), child: _thumb(i)),
                ),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: shown.length,
                separatorBuilder: (context, i) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _thumb(i),
              ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.image, required this.url, required this.height, required this.onOpen});
  final EntityImage image;
  final String? url;
  final double height;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    // Unknown sizes draw square; a panorama is held to a readable width.
    final width = height * (image.aspectRatio ?? 1).clamp(0.5, 2.0);
    final url = this.url;
    final label = image.title.trim();
    return Press(
      onPressed: onOpen,
      semanticLabel: label.isEmpty ? 'Open picture' : 'Open $label',
      builder: (context, pressed) => AnimatedOpacity(
        duration: DsMotion.duration,
        opacity: pressed ? 0.8 : 1,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Ds.raise,
            border: Border.all(color: Ds.edge),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          clipBehavior: Clip.antiAlias,
          child: url == null
              ? null
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, _) => const SizedBox.shrink(),
                ),
        ),
      ),
    );
  }
}
