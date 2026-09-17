import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Wisp's tasks, in the desk's menu order: from the book as it stands to
/// what it adds up to. The descriptions are the desk's page subtitles.
enum WispPage {
  lineEditing('Line editing', 'Craft notes on each chapter, to accept one at a time', LucideIcons.penLine),
  theme('Theme', 'The themes the book carries, and how they develop', LucideIcons.sparkles),
  pacing('Pacing', "The book's rhythm as a wave", LucideIcons.activity),
  genre('Genre expectations', 'Which promises of its genres the book keeps', LucideIcons.library),
  continuity('Continuity', 'Plot holes and continuity errors', LucideIcons.scanSearch),
  reverseOutline('Reverse outline', 'The manuscript read back at the length you need', LucideIcons.listTree);

  const WispPage(this.label, this.description, this.icon);
  final String label;
  final String description;
  final IconData icon;
}
