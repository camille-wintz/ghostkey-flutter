import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../ds/tokens.dart';
import '../../../rewards/cat_picture.dart';
import '../../../rewards/providers.dart';
import '../../../ui/press.dart';
import 'cats_screen.dart';

/// The newest cat, beside "Where you left off" (Cleo, 2026-10-08 — it was a
/// section of its own under the words, with a line on how a cat is earned).
/// Before the first, a cat's shape in the same medallion, so the first cat
/// arrives in the frame that has been waiting for it. The desk's LatestCat
/// medallion, without words; the tile is the door to the shelf.
class CatTile extends ConsumerWidget {
  const CatTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(catsProvider).value?.firstOrNull;
    final placeholder = ref.watch(catCatalogueProvider).value?.firstOrNull;

    return Press(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CatsScreen())),
      semanticLabel: latest != null ? '${latest.name}, your latest cat — all cats' : 'All cats',
      builder: (context, pressed) => AnimatedContainer(
        duration: DsMotion.duration,
        width: 88,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pressed ? Ds.raise : Ds.panel,
          borderRadius: BorderRadius.circular(DsGeom.radius),
          border: Border.all(color: pressed ? Ds.edgeHi : Ds.edge),
        ),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.2, -0.3),
              colors: [Color.lerp(Ds.surf, Ds.accent, 0.28)!, Ds.panel],
              stops: const [0, 0.7],
            ),
            boxShadow: [BoxShadow(color: Ds.accentMix(25), blurRadius: 18)],
          ),
          child: switch ((latest, placeholder)) {
            (final cat?, _) => SizedBox.square(dimension: 50, child: CatPicture(cat)),
            (null, final shape?) => SizedBox.square(
                dimension: 45,
                child: SvgPicture.string(
                  shape.silhouette,
                  colorFilter: ColorFilter.mode(Ds.raise, BlendMode.srcIn),
                  semanticsLabel: 'A cat still to earn',
                ),
              ),
            _ => null,
          },
        ),
      ),
    );
  }
}
