import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/press.dart';
import '../../veil/roster.dart';
import '../../veil/tone.dart';
import 'entity_portrait.dart';
import 'veil_presence_bar.dart';

/// One entity in the roster: its portrait, its name, the dossier's one-line
/// summary, and how present it is in the book being measured. An entity the
/// series knows but this book has not mentioned reads "series" rather than a
/// bare 0 the author would take for a bug.
class VeilEntityRow extends StatelessWidget {
  const VeilEntityRow({
    super.key,
    required this.entity,
    required this.seriesId,
    required this.count,
    required this.peak,
    required this.elsewhere,
    required this.summary,
    required this.onOpen,
  });

  final BibleEntity entity;
  final String? seriesId;

  /// Chapters mentioning it in the book the roster is measured against.
  final int count;

  /// The busiest entity in that book, for the bar's scale.
  final int peak;
  final bool elsewhere;

  /// The dossier's opening line, or empty — which is itself the signal that
  /// nothing has read into this one yet.
  final String summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final name = titleCase(entity.name);
    return Press(
      onPressed: onOpen,
      semanticLabel: name,
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: pressed ? Ds.veil : const Color(0x00000000),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          children: [
            EntityPortrait(seriesId: seriesId, assetId: entity.imageAssetId, initial: name, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsStyle.prose(DsText.body, color: Ds.ink),
                  ),
                  if (summary.isNotEmpty)
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsStyle.ui(DsText.eyebrow, color: Ds.low),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(elsewhere ? 'series' : '$count', style: DsStyle.ui(DsText.eyebrow, color: Ds.faint)),
                const SizedBox(height: 4),
                VeilPresenceBar(fraction: presenceFraction(count, peak), tone: typeTone(entity.type), width: 32),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
