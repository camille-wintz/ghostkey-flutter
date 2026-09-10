import 'json.dart';

// What the author said about themselves in the first-run flow. Mirrors the
// contract's `AuthorProfile` (GET / PUT /api/me/profile).
//
// Account state, not device state — which is the opposite call from the welcome
// notices, whose "seen" flags live in a local JSON file on purpose
// (lib/access/welcome_notices.dart). The difference is worth knowing: those
// record what a screen has SHOWN, these are answers a person gave, and they
// have to reach a phone they have never signed into.
//
// Every field is nullable. An account that has answered nothing and one that
// predates onboarding read the same, and neither is an error.

/// How much of this the author says they have done before.
enum Experience {
  experienced,
  beginner;

  static Experience? fromWire(String? value) => switch (value) {
        'experienced' => Experience.experienced,
        'beginner' => Experience.beginner,
        _ => null,
      };

  String get wire => name;
}

/// How their first book got here. Null on the guided branch, which starts
/// neither way — the flow makes the project on the author's behalf.
enum StartMode {
  import,
  newBook;

  static StartMode? fromWire(String? value) => switch (value) {
        'import' => StartMode.import,
        'new' => StartMode.newBook,
        _ => null,
      };

  String get wire => this == StartMode.newBook ? 'new' : 'import';
}

/// What they came to do. The author's word, never a room name: the desk has
/// Mara and Glamour and this phone does not, so each client maps these to its
/// own rooms (see lib/screens/onboarding/intents.dart).
enum Intent {
  plot,
  draft,
  worldbuild,
  pitch,
  guided;

  static Intent? fromWire(String? value) => switch (value) {
        'plot' => Intent.plot,
        'draft' => Intent.draft,
        'worldbuild' => Intent.worldbuild,
        'pitch' => Intent.pitch,
        'guided' => Intent.guided,
        _ => null,
      };

  String get wire => name;
}

class AuthorProfile {
  const AuthorProfile({
    this.experience,
    this.startMode,
    this.intent,
    this.firstProjectId,
    this.completedAt,
    this.skippedAt,
  });

  final Experience? experience;
  final StartMode? startMode;
  final Intent? intent;
  final String? firstProjectId;
  final String? completedAt;
  final String? skippedAt;

  /// Whether the first-run flow is still owed. Both marks absent is the only
  /// state that means "ask"; anything else has been answered or opted out of.
  bool get owed => completedAt == null && skippedAt == null;

  static AuthorProfile fromJson(Json json) => AuthorProfile(
        experience: Experience.fromWire(json['experience'] as String?),
        startMode: StartMode.fromWire(json['start_mode'] as String?),
        intent: Intent.fromWire(json['intent'] as String?),
        firstProjectId: json['first_project_id'] as String?,
        completedAt: json['completed_at'] as String?,
        skippedAt: json['skipped_at'] as String?,
      );
}
