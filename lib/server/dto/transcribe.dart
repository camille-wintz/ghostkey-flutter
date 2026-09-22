import 'json.dart';

/// One earlier chunk of a dictation session, as the server reported it.
/// Echoed back with the next chunk as the `turns` field of POST /api/transcribe.
class TranscriptTurn {
  const TranscriptTurn({required this.verbatim, required this.cleaned});
  final String verbatim;
  final String cleaned;

  Json toJson() => {'verbatim': verbatim, 'cleaned': cleaned};
}

/// POST /api/transcribe response. `verbatim` is present on the Gemini
/// pipeline only; the client falls back to `text`. `quotaRemaining` is the
/// seconds of dictation left this week after this chunk was charged — null
/// when the plan does not count dictation. `quotaRead` is false when the
/// field is absent (a server older than it), which is no reading at all
/// rather than a null one.
class TranscribeResponse {
  const TranscribeResponse({required this.text, required this.verbatim, this.quotaRemaining, this.quotaRead = false});
  final String text;
  final String? verbatim;
  final int? quotaRemaining;
  final bool quotaRead;

  static TranscribeResponse fromJson(Json json) => TranscribeResponse(
        text: asString(json['text']),
        verbatim: json['verbatim'] as String?,
        quotaRemaining: (json['quota_remaining'] as num?)?.toInt(),
        quotaRead: json.containsKey('quota_remaining'),
      );
}

/// POST /api/transcribe/paragraph response: the paragraph to write back,
/// unchanged when nothing needed repair (or the model failed).
class ParagraphResponse {
  const ParagraphResponse({required this.paragraph});
  final String paragraph;

  static ParagraphResponse fromJson(Json json) => ParagraphResponse(paragraph: asString(json['paragraph']));
}
