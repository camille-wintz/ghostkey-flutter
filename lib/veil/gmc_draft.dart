import 'package:flutter/widgets.dart';

import '../server/dto/bible.dart';

/// The GMC editor's draft — the phone web's `useGmcDraft`: the author's
/// answers as it opened, the dossier's as suggestions, and the cells that
/// changed — the only ones Save writes, so an answer edited on the desk
/// meanwhile is not undone. An emptied cell is a change: it clears the
/// author's answer.
class GmcDraft {
  GmcDraft({required Map<String, String> authored, required List<DossierGlanceItem> glance})
      : _initial = {for (final label in labels) label: (authored[label] ?? '').trim()},
        _suggested = {for (final cell in glance) cell.label: cell.value.trim()} {
    for (final label in labels) {
      _fields[label] = TextEditingController(text: _initial[label]);
    }
  }

  /// Every cell, question by question, external before internal.
  static final List<String> labels = [
    for (final question in glanceGmcQuestions)
      for (final side in glanceGmcSides) gmcLabel(side, question),
  ];

  final Map<String, String> _initial;
  final Map<String, String> _suggested;
  final Map<String, TextEditingController> _fields = {};

  TextEditingController field(String label) => _fields[label]!;

  /// The dossier's answer for [label], or empty.
  String suggestion(String label) => _suggested[label] ?? '';

  /// Fires on every keystroke in any cell.
  late final Listenable changes = Listenable.merge(_fields.values.toList());

  /// The cells that differ from what the screen opened with, trimmed.
  Map<String, String> get changed => {
        for (final label in labels)
          if (_fields[label]!.text.trim() case final value when value != _initial[label]) label: value,
      };

  bool get dirty => changed.isNotEmpty;

  List<String> get _fillable =>
      [for (final label in labels) if (_fields[label]!.text.trim().isEmpty && suggestion(label).isNotEmpty) label];

  /// Some empty cell has a dossier answer to copy in.
  bool get canFill => _fillable.isNotEmpty;

  /// Copy the dossier's answer into every empty cell that has one.
  void fill() {
    for (final label in _fillable) {
      _fields[label]!.text = suggestion(label);
    }
  }

  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
  }
}
