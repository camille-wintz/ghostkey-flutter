import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/media.dart';
import '../../ui/menu_sheet.dart';
import '../../ui/sheet.dart';
import '../../veil/providers.dart';

enum PictureAction { use, rename, move, remove }

/// What a hold on a picture offers, under the picture drawn large with its
/// title and caption. [canUse] is false for a picture already on the card.
Future<PictureAction?> showPictureActions(BuildContext context, {required MediaItem item, required bool canUse}) {
  final url = seriesAssetUrl(item.seriesId, item.thumbAssetId);
  final title = item.title.trim();
  final caption = item.body.trim();
  return showGkSheet<PictureAction>(
    context,
    maxHeightFraction: 0.88,
    header: SheetHeader(eyebrow: 'Picture', onClose: () => Navigator.of(context).pop()),
    builder: (sheet) => SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (url != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DsGeom.radius - 6),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, _, _) => const SizedBox(height: 120),
                  ),
                ),
              ),
            ),
          if (title.isNotEmpty || caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(title, style: DsStyle.ui(DsText.body, color: Ds.hi, weight: FontWeight.w600)),
                  if (title.isNotEmpty && caption.isNotEmpty) const SizedBox(height: 4),
                  if (caption.isNotEmpty)
                    Text(
                      caption,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: DsStyle.ui(DsText.ui, color: Ds.mid),
                    ),
                ],
              ),
            ),
          MenuRow(
            icon: LucideIcons.check,
            label: 'Use this',
            onPressed: canUse ? () => Navigator.of(sheet).pop(PictureAction.use) : null,
          ),
          MenuRow(
            icon: LucideIcons.pencil,
            label: 'Rename',
            onPressed: () => Navigator.of(sheet).pop(PictureAction.rename),
          ),
          MenuRow(
            icon: LucideIcons.folderInput,
            label: 'Move to folder',
            onPressed: () => Navigator.of(sheet).pop(PictureAction.move),
          ),
          MenuRow(
            icon: LucideIcons.trash2,
            label: 'Remove from library',
            destructive: true,
            onPressed: () => Navigator.of(sheet).pop(PictureAction.remove),
          ),
        ],
      ),
    ),
  );
}
