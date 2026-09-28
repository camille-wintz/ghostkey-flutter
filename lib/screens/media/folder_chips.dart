import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../media/folder_filter.dart';
import '../../server/dto/media.dart';
import 'folder_chip.dart';

/// All · Unfiled · each folder · + Folder, in one row that scrolls
/// sideways. A tap sets the grid's folder; a hold on a folder offers its
/// actions.
class FolderChips extends StatelessWidget {
  const FolderChips({
    super.key,
    required this.folders,
    required this.current,
    required this.onPick,
    required this.onHold,
    required this.onNew,
  });
  final List<MediaFolder> folders;
  final FolderFilter current;
  final ValueChanged<FolderFilter> onPick;
  final ValueChanged<MediaFolder> onHold;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final chips = [
      FolderChip(label: 'All', active: current is AllPictures, onTap: () => onPick(FolderFilter.all)),
      FolderChip(label: 'Unfiled', active: current is UnfiledPictures, onTap: () => onPick(FolderFilter.unfiled)),
      for (final folder in folders)
        FolderChip(
          label: folder.name,
          icon: LucideIcons.folder,
          active: current == InFolder(folder.id),
          onTap: () => onPick(InFolder(folder.id)),
          onHold: () => onHold(folder),
        ),
      FolderChip(label: 'Folder', icon: LucideIcons.plus, active: false, onTap: onNew),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: chips.length,
        separatorBuilder: (context, i) => const SizedBox(width: 6),
        itemBuilder: (context, i) => chips[i],
      ),
    );
  }
}
