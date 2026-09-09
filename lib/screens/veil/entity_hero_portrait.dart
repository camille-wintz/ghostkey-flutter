import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../veil/providers.dart';

/// The entity's portrait on its page, at reading width. Only drawn when
/// there is one — a giant initial on a page is noise, where in a row it is
/// a placeholder. Display only: adding a portrait goes through the media
/// library, which is a desktop room.
class EntityHeroPortrait extends StatelessWidget {
  const EntityHeroPortrait({super.key, required this.seriesId, required this.assetId});
  final String? seriesId;
  final String assetId;

  @override
  Widget build(BuildContext context) {
    final url = seriesAssetUrl(seriesId, assetId);
    if (url == null) return const SizedBox.shrink();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280, maxHeight: 280),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Ds.raise,
              border: Border.all(color: Ds.edge),
              borderRadius: BorderRadius.circular(DsGeom.radius),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
