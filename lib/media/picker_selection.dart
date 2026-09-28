import '../server/dto/media.dart';

// What the picker has picked, apart from how it is drawn. A single picker
// (a portrait, the chat) hands back the first tap; a multi picker (a
// gallery) toggles and hands back on its Add. Marked pictures — already on
// the card — are drawn ticked and cannot be picked twice.

class PickerSelection {
  PickerSelection({required this.multi, Set<String> marked = const {}}) : marked = Set.unmodifiable(marked);

  final bool multi;
  final Set<String> marked;
  final List<MediaItem> _picked = [];

  /// In the order they were picked, which is the order a gallery adds them.
  List<MediaItem> get picked => List.unmodifiable(_picked);

  bool isMarked(String id) => marked.contains(id);

  bool isPicked(String id) => _picked.any((i) => i.id == id);

  /// A tap on a picture. Answers the pick to hand back at once (a single
  /// picker), or null when the picker stays up (a toggle, or a marked
  /// picture, which a tap does nothing to).
  List<MediaItem>? tap(MediaItem item) {
    if (isMarked(item.id)) return null;
    if (!multi) return [item];
    if (isPicked(item.id)) {
      _picked.removeWhere((i) => i.id == item.id);
    } else {
      _picked.add(item);
    }
    return null;
  }

  /// A picture that just arrived — an upload, a finished draw. It is picked
  /// without handing back, so the author sees it before it is used: added
  /// to the pick in a multi picker, the pick itself in a single one.
  void land(MediaItem item) {
    if (isMarked(item.id)) return;
    if (!multi) _picked.clear();
    if (!isPicked(item.id)) _picked.add(item);
  }

  /// A picture that left the library while picked.
  void forget(String id) => _picked.removeWhere((i) => i.id == id);

  /// The title bar's commit, or null when there is nothing to commit:
  /// "Add 3" on a gallery, "Use this" on a single picker holding a landed
  /// picture.
  String? get commitLabel {
    if (_picked.isEmpty) return null;
    return multi ? 'Add ${_picked.length}' : 'Use this';
  }
}
