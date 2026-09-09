import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../veil/providers.dart';

/// A small square portrait — the roster row's, the tie card's. The series
/// asset when there is one, the name's initial when not.
class EntityPortrait extends StatelessWidget {
  const EntityPortrait({
    super.key,
    required this.seriesId,
    required this.assetId,
    required this.initial,
    required this.size,
  });

  final String? seriesId;
  final String? assetId;
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = seriesAssetUrl(seriesId, assetId);
    final letter = Center(
      child: Text(
        initial.isEmpty ? '?' : initial.characters.first,
        style: DsStyle.prose(DsStep(size * 0.42, size * 0.5), color: Ds.low),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Ds.raise,
        border: Border.all(color: Ds.edge),
        borderRadius: BorderRadius.circular(size / 4.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? letter
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (context, _, _) => letter),
    );
  }
}
