import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Mara's pages, in the desk's order: the plan in prose, the plan as beats,
/// and the chapters either becomes.
enum MaraPage {
  outline('Outline', 'Your story in prose', LucideIcons.alignLeft),
  cards('Cards', 'Beats on a board', LucideIcons.layoutGrid),
  chapters('Chapters', 'The book, chapter by chapter', LucideIcons.listOrdered);

  const MaraPage(this.label, this.description, this.icon);
  final String label;
  final String description;
  final IconData icon;
}
