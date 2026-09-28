import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../media/library.dart';
import '../../media/photo.dart';
import '../../server/dto/bible.dart';
import '../../server/errors.dart';
import '../../server/media/api.dart';
import '../../ui/notice_modal.dart';
import '../../veil/entity_writes.dart';
import '../media/library_picker_screen.dart';
import 'portrait_sheet.dart';

// A card's pictures, written from its page while editing: the portrait's
// four ways, the gallery's Add, its order, and the viewer's two actions.
// Every picture is a library item on the card by reference — a photo taken
// here goes into the library first, as every picture does — and every write
// is the card PATCH followed by a re-read of the bible (`editPictures`), so
// the page shows the server's card and never one patched here.

void _unsaved(BuildContext context, Object e) {
  if (!context.mounted) return;
  unawaited(showNoticeModal(
    context,
    eyebrow: 'Veil',
    title: 'That did not save',
    action: 'Got it',
    children: [NoticeText(e is PhotoUnreadable ? PhotoUnreadable.message : messageFor(e))],
  ));
}

/// The portrait's sheet, and whatever was chosen from it. [prompt] is the
/// card's appearance, which seeds a drawing. [onBusy] brackets the part the
/// page should show as working — a photo uploading, the card re-reading.
Future<void> editPortrait(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required BibleEntity entity,
  required String name,
  required String prompt,
  required ValueChanged<bool> onBusy,
}) async {
  final choice = await showPortraitSheet(context, name: name, hasPortrait: entity.imageItemId != null);
  if (choice == null || !context.mounted) return;
  final container = ProviderScope.containerOf(context, listen: false);

  Future<void> write(Future<void> Function() step) async {
    onBusy(true);
    try {
      await step();
    } catch (e) {
      if (context.mounted) _unsaved(context, e);
    } finally {
      onBusy(false);
    }
  }

  switch (choice) {
    case PortraitChoice.library || PortraitChoice.draw:
      final picked = await openLibraryPicker(
        context,
        projectId: projectId,
        prompt: prompt,
        drawSize: DrawSize.portrait,
        openOnDraw: choice == PortraitChoice.draw,
      );
      if (picked case [final item, ...] when context.mounted) {
        await write(() => editPictures(ref, projectId, entity.id, imageItemId: item.id));
      }
    case PortraitChoice.camera:
      final PickedPhoto? photo;
      try {
        photo = await pickPhoto(PhotoSource.camera);
      } catch (e) {
        if (context.mounted) _unsaved(context, e);
        return;
      }
      if (photo == null || !context.mounted) return;
      await write(() async {
        final item = await uploadPicture(container, projectId, photo!);
        await editPictures(ref, projectId, entity.id, imageItemId: item.id);
      });
    case PortraitChoice.remove:
      await write(() => editPictures(ref, projectId, entity.id, clearImage: true));
  }
}

/// More pictures on the gallery, from the library picker. The ones already
/// on the card are shown ticked there. A gallery holds 24; past that the
/// server takes the first ones and says which it refused.
Future<void> addToGallery(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required BibleEntity entity,
  required ValueChanged<bool> onBusy,
}) async {
  final picked = await openLibraryPicker(
    context,
    projectId: projectId,
    multi: true,
    markIds: {for (final i in entity.images) i.itemId},
  );
  if (picked == null || picked.isEmpty || !context.mounted) return;
  onBusy(true);
  try {
    final ids = [for (final i in picked) i.id];
    final refused = await editPictures(ref, projectId, entity.id, addImages: ids);
    if (!context.mounted) return;
    if (refused.any((r) => r.reason == RefusedImageReason.galleryFull)) {
      unawaited(showNoticeModal(
        context,
        eyebrow: 'Gallery',
        title: 'The gallery is full',
        action: 'Got it',
        children: [NoticeText(galleryFullMessage(ids.length - refused.length))],
      ));
    }
  } catch (e) {
    if (context.mounted) _unsaved(context, e);
  } finally {
    onBusy(false);
  }
}

/// What a full gallery says, given how many of the pick went on.
String galleryFullMessage(int added) => added > 0
    ? 'A card holds 24 pictures. The first $added ${added == 1 ? 'was' : 'were'} added.'
    : 'A card holds 24 pictures. None of these were added.';

/// Write the order a drag left the strip in. A refusal is said, and the
/// strip goes back to the server's order on its own.
Future<void> orderGallery(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required String entityId,
  required List<String> itemIds,
}) async {
  try {
    await editPictures(ref, projectId, entityId, imageOrder: itemIds);
  } catch (e) {
    if (context.mounted) _unsaved(context, e);
  }
}

Future<void> setPortraitFrom(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required String entityId,
  required EntityImage image,
}) async {
  try {
    await editPictures(ref, projectId, entityId, imageItemId: image.itemId);
  } catch (e) {
    if (context.mounted) _unsaved(context, e);
  }
}

/// Off this card's gallery; the picture stays in the library.
Future<void> removeFromCard(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required String entityId,
  required EntityImage image,
}) async {
  try {
    await editPictures(ref, projectId, entityId, removeImages: [image.itemId]);
  } catch (e) {
    if (context.mounted) _unsaved(context, e);
  }
}
