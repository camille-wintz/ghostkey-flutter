import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../media/folder_filter.dart';
import '../../media/photo.dart';
import '../../media/picker_selection.dart';
import '../../server/dto/media.dart';
import '../../server/errors.dart';
import '../../ui/button.dart';
import '../../ui/page_notice.dart';
import '../../ui/state_screen.dart';
import 'folder_chips.dart';
import 'library_empty.dart';
import 'library_grid.dart';
import 'library_search.dart';

/// The Media library tab, top to bottom: the search, the folder chips, the
/// grid, and the bar that adds a picture. A projection of the picker's
/// state; every decision is the picker's.
class LibraryTabView extends StatelessWidget {
  const LibraryTabView({
    super.key,
    required this.search,
    required this.onQuery,
    required this.folders,
    required this.folder,
    required this.onFolder,
    required this.onFolderHold,
    required this.onNewFolder,
    required this.pictures,
    required this.searching,
    required this.libraryEmpty,
    required this.selection,
    required this.pending,
    required this.onTap,
    required this.onHold,
    required this.onAdd,
    required this.onPhoto,
    required this.onDraw,
    required this.onRetry,
    this.notice,
  });

  final TextEditingController search;
  final ValueChanged<String> onQuery;
  final List<MediaFolder> folders;
  final FolderFilter folder;
  final ValueChanged<FolderFilter> onFolder;
  final ValueChanged<MediaFolder> onFolderHold;
  final VoidCallback onNewFolder;

  /// The grid's pictures: the open part of the listing, or the search's.
  final AsyncValue<List<MediaItem>> pictures;
  final bool searching;

  /// The whole library holds no picture — not just this folder.
  final bool libraryEmpty;
  final PickerSelection selection;
  final int pending;
  final ValueChanged<MediaItem> onTap;
  final ValueChanged<MediaItem> onHold;
  final VoidCallback onAdd;
  final ValueChanged<PhotoSource> onPhoto;
  final VoidCallback onDraw;
  final VoidCallback onRetry;

  /// Why the last photo didn't go in.
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (pictures) {
      AsyncValue(:final value?) when value.isNotEmpty || pending > 0 => LibraryGrid(
          items: value,
          selection: selection,
          pending: pending,
          onTap: onTap,
          onHold: onHold,
        ),
      AsyncValue(hasValue: true) when searching => const StateScreen(message: 'Nothing matches.'),
      AsyncValue(hasValue: true) when libraryEmpty => LibraryEmpty(onPhoto: onPhoto, onDraw: onDraw),
      AsyncValue(hasValue: true) => StateScreen(
          message: folder is UnfiledPictures ? 'Every picture is in a folder.' : 'Nothing in this folder yet.',
          detail: 'Add a picture here, or move one in from All.',
        ),
      AsyncValue(:final error?) => StateScreen(
          message: "The library wouldn't load.",
          detail: messageFor(error),
          actionLabel: 'Try again',
          onAction: onRetry,
        ),
      _ => const StateScreen(spinner: true, message: 'Opening the library…'),
    };

    return Column(
      children: [
        LibrarySearch(controller: search, onChanged: onQuery),
        FolderChips(
          folders: folders,
          current: folder,
          onPick: onFolder,
          onHold: onFolderHold,
          onNew: onNewFolder,
        ),
        if (notice case final notice?)
          Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: PageNotice(notice, error: true)),
        Expanded(child: body),
        Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.paddingOf(context).bottom),
          decoration: BoxDecoration(
            color: Ds.panel,
            border: Border(top: BorderSide(color: Ds.edge)),
          ),
          child: GkButton(
            label: 'Add a picture',
            wide: true,
            variant: ButtonVariant.outline,
            leading: Icon(LucideIcons.imagePlus, size: 16, color: Ds.soft),
            onPressed: onAdd,
          ),
        ),
      ],
    );
  }
}
