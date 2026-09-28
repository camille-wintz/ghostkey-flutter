import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';
import '../../veil/providers.dart';

/// The entity's portrait on its page, at reading width. While reading it is
/// only drawn when there is one — a giant initial on a page is noise, where
/// in a row it is a placeholder. While editing it is the portrait's door
/// ([onEdit]): the portrait with a pencil on it, or an empty frame that asks
/// for one. Every picture comes from the series' media library.
class EntityHeroPortrait extends StatelessWidget {
  const EntityHeroPortrait({super.key, required this.seriesId, required this.assetId, this.onEdit, this.busy = false});
  final String? seriesId;
  final String? assetId;
  final VoidCallback? onEdit;

  /// A portrait is being put on — a photo uploading, the card re-reading.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final url = seriesAssetUrl(seriesId, assetId);
    final onEdit = this.onEdit;
    if (url == null && onEdit == null) return const SizedBox.shrink();
    final frame = AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Ds.raise,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null)
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, _, _) => const SizedBox.shrink(),
              )
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.imagePlus, size: 26, color: Ds.low),
                  const SizedBox(height: 8),
                  Text('Add a portrait', style: DsStyle.ui(DsText.ui, color: Ds.mid)),
                ],
              ),
            if (busy)
              ColoredBox(
                color: const Color(0x99000000),
                child: Center(
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent),
                  ),
                ),
              )
            else if (url != null && onEdit != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Ds.panel,
                    border: Border.all(color: Ds.edgeHi),
                    borderRadius: BorderRadius.circular(DsGeom.radius),
                  ),
                  child: Icon(LucideIcons.pencil, size: 14, color: Ds.soft),
                ),
              ),
          ],
        ),
      ),
    );
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: url == null ? 160 : 280, maxHeight: url == null ? 160 : 280),
        child: onEdit == null
            ? frame
            : Press(
                onPressed: busy ? null : onEdit,
                semanticLabel: url == null ? 'Add a portrait' : 'Change the portrait',
                builder: (context, pressed) => AnimatedOpacity(
                  duration: DsMotion.duration,
                  opacity: pressed ? 0.8 : 1,
                  child: frame,
                ),
              ),
      ),
    );
  }
}
