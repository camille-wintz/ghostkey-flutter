import 'json.dart';

/// `NextScene` in openapi.yaml: what "Find me a scene to write" came back
/// with. [documentId] is the chapter to open; the caret goes at its end.
enum NextSceneKind { unwritten, transition, continue_ }

class NextScene {
  const NextScene({
    required this.kind,
    required this.spot,
    required this.documentId,
    required this.chapter,
    required this.headline,
    required this.prompt,
  });

  final NextSceneKind kind;

  /// The spot's key: passed back in `skip`, or to the marks route. `continue`
  /// for the end of the book, which can't be marked.
  final String spot;
  final String documentId;
  final String chapter;
  final String headline;
  final String prompt;

  factory NextScene.fromJson(Json json) => NextScene(
        kind: switch (json['kind']) {
          'unwritten' => NextSceneKind.unwritten,
          'transition' => NextSceneKind.transition,
          _ => NextSceneKind.continue_,
        },
        spot: asString(json['spot']),
        documentId: asString(json['document_id']),
        chapter: asString(json['chapter']),
        headline: asString(json['headline']),
        prompt: asString(json['prompt']),
      );
}

/// The author's word on a spot passed with "Next spot": `later` sends it to the
/// back of the queue, `never` retires it. Stored server-side.
enum SpotMark { later, never }
