import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/chat.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';

// The "recall" trace — PhantomMemory reaching into the manuscript. Live: the
// rows stream in with a spinner on the open step. Done: one quiet line
// ("Recalled from Chapter 3 · "dagger"") that expands on tap.

final RegExp _reading = RegExp(r'^reading\s+', caseSensitive: false);
final RegExp _searchingFor = RegExp(r'^searching for\s+', caseSensitive: false);
final RegExp _recalling = RegExp(r'^recalling\s+', caseSensitive: false);
final RegExp _lookingUp = RegExp(r'^looking up\s+', caseSensitive: false);
final RegExp _inTheBible = RegExp(r'\s+in the world bible$', caseSensitive: false);
final RegExp _lookingThrough = RegExp(r'^looking through the library(?: for)?\s*', caseSensitive: false);

/// Short token for the collapsed line, derived from the step's summary the
/// way the desktop rail does it.
String shortLabel(ChatToolStep step) {
  final summary = step.summary;
  return switch (step.tool) {
    'read_outline' => 'outline',
    'read_novel' => 'whole novel',
    'read_author_outline' => "author's outline",
    'read_story_map' => 'story map',
    'edit_outline' => 'outline correction',
    'save_note' => 'a saved note',
    'read_library_item' => 'a library item',
    'add_to_library' => 'an addition to the library',
    'read_attachment' => step.detail?.split(' · ').firstOrNull?.replaceAll('"', '') ?? 'an attachment',
    'search_library' => _or(summary.replaceFirst(_lookingThrough, '').trim(), 'the library'),
    'search' => _or(summary.replaceFirst(_searchingFor, '').trim(), 'the manuscript'),
    'semantic_search' => _or(summary.replaceFirst(_recalling, '').trim(), 'by meaning'),
    'lookup_entity' =>
      _or(summary.replaceFirst(_lookingUp, '').replaceFirst(_inTheBible, '').trim(), 'the world bible'),
    _ => _or(summary.replaceFirst(_reading, '').trim(), 'a chapter'),
  };
}

String _or(String value, String fallback) => value.isEmpty ? fallback : value;

class RecallRail extends StatefulWidget {
  const RecallRail({super.key, required this.steps, required this.live});
  final List<ChatToolStep> steps;

  /// True while the turn is in flight: the rail stays open.
  final bool live;

  @override
  State<RecallRail> createState() => _RecallRailState();
}

class _RecallRailState extends State<RecallRail> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    if (steps.isEmpty) return const SizedBox.shrink();
    final open = widget.live || _expanded;
    final running = widget.live && steps.any((s) => s.status == ChatToolStepStatus.running);

    if (!open) {
      return Press(
        onPressed: () => setState(() => _expanded = true),
        builder: (context, pressed) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Opacity(
            opacity: pressed ? 0.7 : 1,
            child: Row(
              children: [
                Icon(LucideIcons.chevronRight, size: 11, color: Ds.faint),
                const SizedBox(width: 6),
                const Eyebrow('Recalled from', semibold: false),
                const SizedBox(width: 6),
                Expanded(child: UiText(steps.map(shortLabel).join(' · '), step: DsText.ui, color: Ds.mid, maxLines: 1)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.live)
            Press(
              onPressed: () => setState(() => _expanded = false),
              builder: (context, pressed) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Opacity(
                  opacity: pressed ? 0.7 : 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.chevronDown, size: 11, color: Ds.faint),
                      const SizedBox(width: 6),
                      const Eyebrow('Recall', semibold: false),
                    ],
                  ),
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: running ? Ds.accentMix(55) : Ds.edge, width: 1.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < steps.length; i++)
                  Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 4), child: _RailRow(step: steps[i])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailRow extends StatelessWidget {
  const _RailRow({required this.step});
  final ChatToolStep step;

  @override
  Widget build(BuildContext context) {
    final error = step.status == ChatToolStepStatus.error;
    final base = DsStyle.ui(DsText.ui, color: error ? Ds.destructive : Ds.mid);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 16, height: 18, child: Center(child: _StatusGlyph(status: step.status))),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: step.summary,
              children: [
                if (step.detail != null) TextSpan(text: ' · ${step.detail}', style: TextStyle(color: Ds.faint)),
                if (step.error != null) TextSpan(text: ' — ${step.error}', style: TextStyle(color: Ds.destructive)),
              ],
            ),
            style: base,
          ),
        ),
      ],
    );
  }
}

class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({required this.status});
  final ChatToolStepStatus status;

  @override
  Widget build(BuildContext context) => switch (status) {
        ChatToolStepStatus.running => SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Ds.accent),
          ),
        ChatToolStepStatus.error => Icon(LucideIcons.circleAlert, size: 14, color: Ds.destructive),
        ChatToolStepStatus.done => Icon(LucideIcons.check, size: 14, color: Ds.accent),
      };
}
