import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';

// The empty thread: what the room is, and four starter prompts. Two sets,
// the desktop's — one for a manuscript, one for a book that is still a plan.

const List<String> _manuscriptSuggestions = [
  'Where does the pacing sag?',
  "Summarize chapter 3's arc",
  'List the unresolved threads',
  'Which characters disappear for too long?',
];

const List<String> _planningSuggestions = [
  'What do you think of my outline?',
  'Which beats are still empty, and which matter most?',
  'Help me plot using a three-act structure',
  'Where does my plan go “and then” instead of “therefore”?',
];

class ChatIntro extends StatelessWidget {
  const ChatIntro({super.key, required this.planning, required this.onPick, this.disabled = false});

  /// No chapters yet — the intro speaks to the plan, not the draft.
  final bool planning;
  final ValueChanged<String> onPick;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final suggestions = planning ? _planningSuggestions : _manuscriptSuggestions;
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 36, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Eyebrow('Phantom Memory', color: Ds.accent),
          const SizedBox(height: 8),
          Text(
            planning ? 'Consult the memory of your plan.' : 'Consult the memory of your manuscript.',
            style: DsStyle.prose(DsText.title, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          UiText(
            planning
                ? 'It reads your outline and story map, and answers from them.'
                : 'It reads your chapters as it needs them, and answers from the book itself.',
            color: Ds.mid,
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < suggestions.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: Press(
                onPressed: () => onPick(suggestions[i]),
                enabled: !disabled,
                builder: (context, pressed) => AnimatedContainer(
                  duration: DsMotion.duration,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: pressed ? Ds.accentMix(12) : Ds.panel,
                    border: Border.all(color: pressed ? Ds.edgeHi : Ds.edge),
                    borderRadius: BorderRadius.circular(DsGeom.radius),
                  ),
                  child: Opacity(
                    opacity: disabled ? 0.5 : 1,
                    child: UiText(suggestions[i], step: DsText.ui, color: Ds.soft),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
