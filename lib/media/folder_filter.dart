import '../server/dto/media.dart';

// Which part of the library the picker's grid shows: everything, what is in
// no folder, or one folder. Its wire form is what the device remembers.

sealed class FolderFilter {
  const FolderFilter();

  static const FolderFilter all = AllPictures();
  static const FolderFilter unfiled = UnfiledPictures();

  /// Whether [item] belongs in this part of the library.
  bool admits(MediaItem item);

  /// The folder a picture made while this part is open lands in — null for
  /// none.
  String? get landingFolderId;

  String get wire;

  /// A remembered filter, back. A folder that no longer exists is [all], so
  /// a deleted folder is never the grid's answer.
  static FolderFilter fromWire(String? wire, {Iterable<MediaFolder> folders = const []}) {
    if (wire == 'unfiled') return unfiled;
    if (wire != null && wire.startsWith('folder:')) {
      final id = wire.substring('folder:'.length);
      if (folders.any((f) => f.id == id)) return InFolder(id);
    }
    return all;
  }
}

final class AllPictures extends FolderFilter {
  const AllPictures();

  @override
  bool admits(MediaItem item) => true;

  @override
  String? get landingFolderId => null;

  @override
  String get wire => 'all';
}

final class UnfiledPictures extends FolderFilter {
  const UnfiledPictures();

  @override
  bool admits(MediaItem item) => item.folderId == null;

  @override
  String? get landingFolderId => null;

  @override
  String get wire => 'unfiled';
}

final class InFolder extends FolderFilter {
  const InFolder(this.folderId);
  final String folderId;

  @override
  bool admits(MediaItem item) => item.folderId == folderId;

  @override
  String? get landingFolderId => folderId;

  @override
  String get wire => 'folder:$folderId';

  @override
  bool operator ==(Object other) => other is InFolder && other.folderId == folderId;

  @override
  int get hashCode => folderId.hashCode;
}

/// The pictures the grid shows under [filter], in the listing's order
/// (newest first). Only pictures: the phone neither shows nor makes the
/// library's other kinds yet.
List<MediaItem> picturesIn(MediaLibrary library, FolderFilter filter) =>
    library.items.where((i) => i.isImage && filter.admits(i)).toList();

/// The folders as the chips list them: by the author's order, then by name.
List<MediaFolder> foldersInOrder(Iterable<MediaFolder> folders) => [...folders]
  ..sort((a, b) {
    final bySort = a.sortIndex.compareTo(b.sortIndex);
    return bySort != 0 ? bySort : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
