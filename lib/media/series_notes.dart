import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/words.dart';
import '../server/dto/media.dart';
import '../server/media/api.dart';

// The series notes: the library's uploaded text files, which every book of
// the series lists beside its own notes (`series_note`, decided by the
// server). The phone reads them; editing one stays on the desk.

/// The series notes in a listing, in the library's order.
List<MediaItem> seriesNotesOf(MediaLibrary? library) =>
    [for (final item in library?.items ?? const <MediaItem>[]) if (item.seriesNote) item];

typedef SeriesNoteKey = ({String projectId, String itemId});

/// One series note, whole body, and its length in words — counted here once
/// rather than in a build, since a body runs to millions of characters.
final seriesNoteProvider = FutureProvider.autoDispose.family<({MediaItem item, int words}), SeriesNoteKey>((ref, key) async {
  final item = (await getMediaItem(key.projectId, key.itemId)).item;
  return (item: item, words: countWords(item.body));
});
