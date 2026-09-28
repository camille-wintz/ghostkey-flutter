import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/menu_sheet.dart';
import '../../ui/sheet.dart';

enum PortraitChoice { library, camera, draw, remove }

/// The ways to a card's portrait, every one through the media library.
/// Remove is offered only when there is a portrait, and says the picture
/// stays in the library.
Future<PortraitChoice?> showPortraitSheet(BuildContext context, {required String name, required bool hasPortrait}) =>
    showGkSheet<PortraitChoice>(
      context,
      header: SheetHeader(eyebrow: 'Portrait', trailing: name, onClose: () => Navigator.of(context).pop()),
      builder: (sheet) {
        void pick(PortraitChoice choice) => Navigator.of(sheet).pop(choice);
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MenuRow(
                icon: LucideIcons.images,
                label: 'Choose from your library',
                onPressed: () => pick(PortraitChoice.library),
              ),
              MenuRow(icon: LucideIcons.camera, label: 'Take a photo', onPressed: () => pick(PortraitChoice.camera)),
              MenuRow(icon: LucideIcons.sparkles, label: 'Draw one', onPressed: () => pick(PortraitChoice.draw)),
              if (hasPortrait) ...[
                MenuRow(
                  icon: LucideIcons.trash2,
                  label: 'Remove portrait',
                  destructive: true,
                  onPressed: () => pick(PortraitChoice.remove),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: Text(
                    'Removing it leaves the picture in your library.',
                    style: DsStyle.ui(DsText.ui, color: Ds.low),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
