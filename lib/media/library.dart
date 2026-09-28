import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../access/capability.dart';
import '../access/quota_refusals.dart';
import '../server/dto/media.dart';
import '../server/errors.dart';
import '../server/media/api.dart';
import '../server/providers.dart';
import '../veil/providers.dart';
import 'access.dart';
import 'folder_filter.dart';
import 'photo.dart';

// The series' media library, as the phone reads and writes it. One read (the
// whole listing), one keyword search, and the writes — each a server call
// followed by a re-read of the listing, awaited, so what the picker shows
// next is the server's answer and never a copy patched here. A removal also
// re-reads the bible, since it takes the picture off every card it was on.
//
// Keyed by project like Veil's reads: the library belongs to the series, but
// it is reached through whichever book is open. The writes take the
// container rather than a widget's ref because they outlive widgets: a
// draw runs for minutes, and the picker that asked may be closed by then.

final libraryProvider = FutureProvider.autoDispose.family<MediaLibrary, String>(
  (ref, projectId) => listMedia(projectId),
);

typedef LibrarySearchKey = ({String projectId, String query, FolderFilter folder});

/// Pictures matching a keyword, in the open part of the library.
final librarySearchProvider = FutureProvider.autoDispose.family<List<MediaItem>, LibrarySearchKey>((ref, key) async {
  final hits = await searchMedia(
    key.projectId,
    key.query,
    folderId: key.folder.landingFolderId,
    unfiledOnly: key.folder is UnfiledPictures,
  );
  return [for (final h in hits) if (h.item.isImage) h.item];
});

/// Re-read the listing and wait for it. Held by a listener while it lands:
/// the read is autoDispose, and a caller with no page watching it (a Veil
/// portrait taken with the camera) would otherwise drop it mid-flight.
Future<void> _reread(ProviderContainer container, String projectId) async {
  container.invalidate(librarySearchProvider);
  container.invalidate(libraryProvider(projectId));
  final held = container.listen(libraryProvider(projectId).future, (_, _) {});
  try {
    await held.read();
  } finally {
    held.close();
  }
}

/// Put a photo in the library, in [folderId] when given, and answer with
/// the item once the listing has it.
Future<MediaItem> uploadPicture(ProviderContainer container, String projectId, PickedPhoto photo, {String? folderId}) async {
  final item = await uploadMedia(projectId, photo.bytes, filename: photo.filename, folderId: folderId);
  await _reread(container, projectId);
  return item;
}

Future<void> renamePicture(ProviderContainer container, String projectId, String itemId, String title) async {
  await patchMediaItem(projectId, itemId, title: title);
  await _reread(container, projectId);
}

/// Into [folderId], or out of every folder when it is null.
Future<void> movePicture(ProviderContainer container, String projectId, String itemId, String? folderId) async {
  await patchMediaItem(projectId, itemId, folderId: folderId, unfile: folderId == null);
  await _reread(container, projectId);
}

/// How many world-bible cards show [itemId] — what a removal asks about
/// first. 0 when the count won't come: the question is still asked, only
/// without the number.
Future<int> cardsShowing(String projectId, String itemId) async {
  try {
    return (await getMediaItem(projectId, itemId)).cards;
  } catch (e) {
    // Best effort: the confirm reads fine without the count.
    debugPrint('[media] card count failed, asking without it: $e');
    return 0;
  }
}

Future<void> removePicture(ProviderContainer container, String projectId, String itemId) async {
  await deleteMediaItem(projectId, itemId);
  container.invalidate(bibleProvider(projectId));
  await _reread(container, projectId);
}

/// A new folder, once the listing has it. `name_taken` when the series
/// already has one called that.
Future<MediaFolder> createFolder(ProviderContainer container, String projectId, String name) async {
  final folder = await createMediaFolder(projectId, name);
  await _reread(container, projectId);
  return folder;
}

Future<void> renameFolder(ProviderContainer container, String projectId, String folderId, String name) async {
  await patchMediaFolder(projectId, folderId, name: name);
  await _reread(container, projectId);
}

/// Its pictures stay in the library, unfiled.
Future<void> deleteFolder(ProviderContainer container, String projectId, String folderId) async {
  await deleteMediaFolder(projectId, folderId);
  await _reread(container, projectId);
}

/// How a draw ended.
sealed class DrawOutcome {
  const DrawOutcome();
}

final class DrawDone extends DrawOutcome {
  const DrawDone(this.item);
  final MediaItem item;
}

/// The plan may not draw; the caller explains the padlock.
final class DrawLocked extends DrawOutcome {
  const DrawLocked(this.state);
  final CapabilityState state;
}

/// No draws left this week. Already explained: the app root shows the
/// quota notice.
final class DrawSpent extends DrawOutcome {
  const DrawSpent();
}

final class DrawFailed extends DrawOutcome {
  const DrawFailed(this.message);
  final String message;
}

/// Draw a picture into the library, through both gates as the desk's
/// `useImageDraw` composes them: the padlock first (may this plan draw?),
/// then the count (is there a draw left?) — and the server's own 403/402
/// after, since the snapshot can be stale. Every draw re-reads the quota,
/// failures too: the server gives back a draw the provider never billed.
Future<DrawOutcome> drawPicture(
  ProviderContainer container,
  String projectId, {
  required String prompt,
  required DrawSize size,
  String? folderId,
}) async {
  final gate = container.read(capabilityProvider(drawCapability));
  if (!gate.granted) return DrawLocked(gate);
  final snapshot = container.read(quotaProvider).value;
  if (snapshot?.feature(drawQuotaFeature)?.remaining == 0) {
    reportQuotaSpent(drawQuotaFeature, snapshot: snapshot);
    return const DrawSpent();
  }
  try {
    final item = await drawMedia(projectId, prompt: prompt, size: size, folderId: folderId);
    await _reread(container, projectId);
    return DrawDone(item);
  } catch (e) {
    if (reportQuotaRefusal(e)) return const DrawSpent();
    return switch (e) {
      ServerError(code: 'plan_insufficient') => DrawLocked(container.read(capabilityProvider(drawCapability))),
      ServerError(code: 'no_image') => const DrawFailed("The model didn't return a picture. That one still counted."),
      ServerError(status: 429 || 502) => const DrawFailed("Couldn't draw right now. Try again in a minute."),
      _ => DrawFailed("Couldn't draw that. ${messageFor(e)}"),
    };
  } finally {
    container.invalidate(quotaProvider);
  }
}
