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
/// clears that cell and a cell not passed is left as it was. `ties` is the
/// whole list, replacing the card's. Throws a
/// `ServerError` with `name_taken` when another card owns [name].
Future<void> editEntity(
  WidgetRef ref,
  String projectId,
  String entityId, {
  String? name,
  String? notes,
  String? description,
  Map<String, String>? gmc,
  List<BibleEntityTie>? ties,
  bool? hidden,
}) async {
  await patchBibleEntity(
    projectId,
    entityId,
    name: name,
    notes: notes,
    description: description,
    gmc: gmc,
    ties: ties,
    hidden: hidden,
  );
  ref.invalidate(bibleProvider(projectId));
  await ref.read(bibleProvider(projectId).future);
}

/// One step of the dossier interview on a card: file [answer] to [answering]
/// (a blank one is a skip) and ask the next question, or stop when [next] is
/// false. A filed answer changes the card's dossier text server-side, so the
/// bible is re-read, awaited, before the next question is shown.
Future<InterviewQuestion?> interviewStep(
  WidgetRef ref,
  String projectId,
  String entityId, {
  InterviewQuestion? answering,
  String answer = '',
  required List<String> asked,
  bool next = true,
}) async {
  final text = answer.trim();
  final question = await interviewEntity(
    projectId,
    entityId,
    answering: answering,
    answer: text.isEmpty ? null : text,
    asked: asked,
    next: next,
  );
  if (text.isNotEmpty && answering != null) {
    ref.invalidate(bibleProvider(projectId));
    await ref.read(bibleProvider(projectId).future);
  }
  return question;
}

/// Write a card's physical description from its portrait and save it as the
/// author's. Null when the model saw no one in the picture — nothing is
/// written then. Throws `no_portrait` when the card's picture won't open.
Future<String?> describeFromPortrait(WidgetRef ref, String projectId, String entityId) async {
  final text = await describeEntityPortrait(projectId, entityId);
  if (text.isEmpty) return null;
  await editEntity(ref, projectId, entityId, description: text);
  return text;
}

/// Change a card's pictures — all of them library items, by id, never
/// copies. [imageItemId] sets the portrait and [clearImage] takes it off
/// (the picture stays in the library); [addImages] / [removeImages] put
/// pictures on or off the gallery and [imageOrder] orders it. Answers with
/// the pictures the server would not put on the card — the gallery's 24 are
/// full, say — after the bible has been re-read.
Future<List<RefusedImage>> editPictures(
  WidgetRef ref,
  String projectId,
  String entityId, {
  String? imageItemId,
  bool clearImage = false,
  List<String>? addImages,
  List<String>? removeImages,
  List<String>? imageOrder,
}) async {
  final written = await patchBibleEntity(
    projectId,
    entityId,
    imageItemId: imageItemId,
    clearImage: clearImage,
    addImages: addImages,
    removeImages: removeImages,
    imageOrder: imageOrder,
  );
  ref.invalidate(bibleProvider(projectId));
  await ref.read(bibleProvider(projectId).future);
  return written.refusedImages;
}
