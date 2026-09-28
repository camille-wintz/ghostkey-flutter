// A card's gallery, reordered by a drag. The server takes the order as item
// ids (`image_order`); ids left out keep their place after these, so the
// whole strip is always sent.

/// [itemIds] with the one at [from] moved to [to], where [to] is the index
/// it ends at — what `onReorderItem` hands over, already adjusted for the
/// row taken out. Out-of-range indexes answer the list unchanged.
List<String> movedOrder(List<String> itemIds, int from, int to) {
  if (from < 0 || from >= itemIds.length || to < 0 || to >= itemIds.length || from == to) {
    return List.of(itemIds);
  }
  final next = List.of(itemIds);
  next.insert(to, next.removeAt(from));
  return next;
}
