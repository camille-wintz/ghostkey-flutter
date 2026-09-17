import 'json.dart';

// A finished `edit_pass` job's answer, as it rides `JobSnapshot.result`
// (EditPassResult / EditNote in the contract).

/// One proposed change. `quote` located exactly once in the subject as the
/// run read it; `suggestion` is absent when the model saw a problem but not
/// the fix.
class EditNote {
  const EditNote({required this.quote, required this.note, required this.category, this.suggestion});
  final String quote;
  final String note;
  final String? suggestion;
  final String category;

  static EditNote fromJson(Json json) => EditNote(
        quote: asString(json['quote']),
        note: asString(json['note']),
        suggestion: json['suggestion'] as String?,
        category: asString(json['category'], 'other'),
      );
}

class EditPassResult {
  const EditPassResult({required this.depth, required this.model, required this.notes, required this.dropped});

  /// `proofread` or `line_edit`.
  final String depth;
  final String model;
  final List<EditNote> notes;
  final int dropped;

  /// Null for a result that is not a pass's — the desk's `resultOf` check.
  static EditPassResult? tryParse(Object? json) {
    if (json is! Map) return null;
    final depth = json['depth'];
    if (json['notes'] is! List || json['model'] is! String || (depth != 'proofread' && depth != 'line_edit')) {
      return null;
    }
    final map = asJson(json);
    return EditPassResult(
      depth: depth as String,
      model: asString(map['model']),
      notes: asJsonList(map['notes']).map(EditNote.fromJson).toList(),
      dropped: asInt(map['dropped']),
    );
  }
}
