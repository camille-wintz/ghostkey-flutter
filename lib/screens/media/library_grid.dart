import 'package:flutter/material.dart';

import '../../media/picker_selection.dart';
import '../../server/dto/media.dart';
import '../../veil/providers.dart';
import 'library_tile.dart';
import 'pending_tile.dart';

/// Three columns of square previews — the bounded copy when there is one —
/// with a spinner tile first for each photo still uploading.
class LibraryGrid extends StatelessWidget {
  const LibraryGrid({
    super.key,
    required this.items,
    required this.selection,
    required this.pending,
    required this.onTap,
    required this.onHold,
  });
  final List<MediaItem> items;
  final PickerSelection selection;
  final int pending;
  final ValueChanged<MediaItem> onTap;
  final ValueChanged<MediaItem> onHold;

  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: pending + items.length,
        itemBuilder: (context, i) {
          if (i < pending) return const PendingTile();
          final item = items[i - pending];
          return LibraryTile(
            key: ValueKey(item.id),
            url: seriesAssetUrl(item.seriesId, item.thumbAssetId),
            title: item.title,
            picked: selection.isPicked(item.id),
            marked: selection.isMarked(item.id),
            onTap: () => onTap(item),
            onHold: () => onHold(item),
          );
        },
      );
}
