import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ui/menu_sheet.dart';

enum FolderAction { rename, delete }

/// What a hold on a folder chip offers.
Future<FolderAction?> showFolderActions(BuildContext context, {required String name}) => showMenuSheet<FolderAction>(
      context,
      title: name,
      entries: const [
        MenuEntry(icon: LucideIcons.pencil, label: 'Rename', value: FolderAction.rename),
        MenuEntry(icon: LucideIcons.trash2, label: 'Delete folder', value: FolderAction.delete, destructive: true),
      ],
    );
