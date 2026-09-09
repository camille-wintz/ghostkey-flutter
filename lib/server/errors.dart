import 'dto/billing.dart';

/// Extra fields a 403 `plan_insufficient` carries, so the message can name the
/// feature and the plan that unlocks it rather than saying "went wrong".
class PlanDenial {
  const PlanDenial({
    this.label,
    this.requiredPlan,
    this.currentPlan,
    this.capability,
    this.feature,
  });

  final String? label;
  final String? requiredPlan;
  final String? currentPlan;
  final String? capability;
  final String? feature;

  static PlanDenial fromJson(Map<String, dynamic> json) => PlanDenial(
        label: json['label'] as String?,
        requiredPlan: json['required_plan'] as String?,
        currentPlan: json['current_plan'] as String?,
        capability: json['capability'] as String?,
        feature: json['feature'] as String?,
      );
}

/// A refusal from the server, with its wire code lifted out of the body.
///
/// `code` is the server's own vocabulary and may grow values this client has
/// never heard of; `messageFor` falls back to a generic line for those rather
/// than crashing on a switch.
class ServerError implements Exception {
  ServerError(
    this.code,
    this.status, [
    String? message,
    this.denial,
    this.retryAfter,
    this.quota,
  ]) : message = message ?? code;

  final String code;
  final int status;
  final String message;
  final PlanDenial? denial;

  /// Seconds to wait, off a 429. The server's number, never a local copy.
  final int? retryAfter;

  /// The 402 body, so the notice can name the counter and its reset day.
  final QuotaExceeded? quota;

  @override
  String toString() => 'ServerError($code, $status): $message';
}

const Map<String, String> _messages = {
  'invalid_json': 'The server could not parse the request.',
  'invalid_body': 'Please check the form and try again.',
  'unauthorized': 'You need to sign in to continue.',
  'invalid_credentials': 'Wrong email or password.',
  'invalid_refresh_token': 'Your session expired. Please sign in again.',
  'email_taken': 'An account with this email already exists.',
  'conflict': 'This item was changed elsewhere. Refresh and try again.',
  'version_conflict':
      'The chapter list changed elsewhere and has been refreshed. Try the move again.',
  'invalid_chapters': 'The server could not read that chapter order.',
  'plan_insufficient': 'This feature is not part of your plan.',
  'rate_limited': 'Too many attempts. Wait a moment and try again.',
  'job_running':
      'Something else is already running on this book. Try again in a moment.',
  'already_verified': 'This address is already verified.',
  'email_not_configured':
      "This Ghostkey server can't send email. Get in touch and we'll verify you by hand.",
  'email_send_failed': "The mail didn't go out. Try again in a moment.",
  'network_error': 'Could not reach the server. Check your connection.',
  'upstream_error': 'The transcription service is unavailable right now.',
  'server_error': 'The server hit a problem. Try again in a moment.',
  'content_too_large': 'That capture is too large.',
  'quota_exceeded': "You've used up this week's chat messages.",
  'chat_empty': 'Write something first.',
  'chat_not_user_turn': 'The last message has to be yours.',
  'invalid_model': 'That model is not available.',
  'refusal': 'The model declined to answer that one.',
  'empty_response': 'The model returned nothing. Try again.',
  'unknown': 'Something went wrong. Please try again.',
};

/// What to tell the author about an error.
String messageFor(Object? err) {
  if (err is ServerError) {
    if (err.code == 'plan_insufficient') return _planMessage(err.denial);
    return _messages[err.code] ?? _messages['unknown']!;
  }
  if (err is StateError) return err.message;
  if (err is Exception) return err.toString();
  return _messages['unknown']!;
}

/// The server owns the feature's name and the plan that opens it, so a feature
/// added after this build shipped still explains itself.
String _planMessage(PlanDenial? denial) {
  final what = denial?.label ?? 'This feature';
  final plan = denial?.requiredPlan;
  return plan != null
      ? '$what is part of ${_titleCase(plan)}.'
      : '$what is not part of your plan.';
}

String _titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
