import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server/bible/api.dart';
import '../server/dto/bible.dart';
import 'providers.dart';

// Veil's writes on one card: add one, or edit the author's fields on one.
// Each is a single-entity route — only what changed is sent, so the phone
// cannot undo an edit made on the desk in between — followed by a re-read of
// the bible, awaited, so the page that shows the result is drawn from the
// server's answer and never from a copy patched here.

/// Add a card by hand and answer with it as the refreshed bible has it. A
/// name the bible already answers to comes back as that existing card.
Future<BibleEntity?> addEntity(
  WidgetRef ref,
  String projectId, {
  required BibleEntityType type,
  required String name,
}) async {
  final written = await createBibleEntity(projectId, type: type, name: name);
  final bible = await ref.refresh(bibleProvider(projectId).future);
  return bible.entities.where((e) => e.id == written.id).firstOrNull;
}

/// Edit the author's fields on one card. `gmc` is per cell: an empty answer
/// clears that cell and a cell not passed is left as it was. Throws a
/// `ServerError` with `name_taken` when another card owns [name].
Future<void> editEntity(
  WidgetRef ref,
  String projectId,
  String entityId, {
  String? name,
  String? notes,
  String? description,
  Map<String, String>? gmc,
  bool? hidden,
}) async {
  await patchBibleEntity(
    projectId,
    entityId,
    name: name,
    notes: notes,
    description: description,
    gmc: gmc,
    hidden: hidden,
  );
  ref.invalidate(bibleProvider(projectId));
  await ref.read(bibleProvider(projectId).future);
}
