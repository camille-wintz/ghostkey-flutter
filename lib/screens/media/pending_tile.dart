import 'package:flutter/material.dart';

import '../../ds/tokens.dart';

/// The grid's first tile while a photo uploads.
class PendingTile extends StatelessWidget {
  const PendingTile({super.key});

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Ds.surf,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius - 6),
        ),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent),
        ),
      );
}
