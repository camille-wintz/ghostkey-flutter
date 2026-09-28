import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../server/dto/media.dart';
import '../../ui/menu_sheet.dart';
import '../../ui/sheet.dart';

/// Where to move a picture: Unfiled, or one of the folders, the one it is
/// in ticked. Resolves with the destination — `folderId` null for Unfiled —
/// or null when closed or when the picture's own place is picked.
Future<({String? folderId})?> showMoveToFolderSheet(
  BuildContext context, {
  required List<MediaFolder> folders,
  required String? current,
}) async {
  final picked = await showGkSheet<({String? folderId})>(
    context,
    header: SheetHeader(eyebrow: 'Move to folder', onClose: () => Navigator.of(context).pop()),
    builder: (sheet) => SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MenuRow(
            icon: current == null ? LucideIcons.check : LucideIcons.inbox,
            label: 'Unfiled',
            onPressed: () => Navigator.of(sheet).pop((folderId: null)),
          ),
          for (final folder in folders)
            MenuRow(
              icon: current == folder.id ? LucideIcons.check : LucideIcons.folder,
              label: folder.name,
              onPressed: () => Navigator.of(sheet).pop((folderId: folder.id)),
            ),
        ],
      ),
    ),
  );
  if (picked == null || picked.folderId == current) return null;
  return picked;
}
