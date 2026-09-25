import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/press.dart';
import '../../veil/providers.dart';
import 'image_viewer_screen.dart';
import 'veil_section.dart';

/// The card's pictures as one strip above the dossier, each at its own
/// shape and one height. Display only: the gallery is filled from the
/// media library, which is a desktop room. A tap opens the picture full size.
class EntityGallery extends StatelessWidget {
  const EntityGallery({super.key, required this.images, required this.seriesId});
  final List<EntityImage> images;
  final String? seriesId;

  static const double _height = 120;

  void _open(BuildContext context, int index) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => ImageViewerScreen(images: images, seriesId: seriesId, initialIndex: index),
        ),
      );

  @override
  Widget build(BuildContext context) => VeilSection(
        title: 'Gallery',
        child: SizedBox(
          height: _height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: images.length,
            separatorBuilder: (context, i) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _Thumb(
              image: images[i],
              url: seriesAssetUrl(seriesId, images[i].thumbAssetId),
              height: _height,
              onOpen: () => _open(context, i),
            ),
          ),
        ),
      );
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
