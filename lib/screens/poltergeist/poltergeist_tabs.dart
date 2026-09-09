import 'package:flutter/widgets.dart';

/// The room's four pages. Order is the tab bar's order.
enum PoltergeistTab { dashboard, words, tasks, plan }

/// Lets a section deep in one tab open another ("All tasks →"), without
/// threading a callback through every panel.
class PoltergeistTabs extends InheritedWidget {
  const PoltergeistTabs({super.key, required this.current, required this.open, required super.child});
  final PoltergeistTab current;
  final void Function(PoltergeistTab tab) open;

  static PoltergeistTabs of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PoltergeistTabs>()!;

  @override
  bool updateShouldNotify(PoltergeistTabs oldWidget) => oldWidget.current != current;
}
