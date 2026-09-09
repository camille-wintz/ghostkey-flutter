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
/// pipeline only; the client falls back to `text`.
class TranscribeResponse {
  const TranscribeResponse({required this.text, required this.verbatim});
  final String text;
  final String? verbatim;

  static TranscribeResponse fromJson(Json json) => TranscribeResponse(
        text: asString(json['text']),
        verbatim: json['verbatim'] as String?,
      );
}
