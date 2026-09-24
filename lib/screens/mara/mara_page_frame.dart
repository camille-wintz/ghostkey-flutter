import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/room_title_bar.dart';

/// A Mara page, full screen: its bar, then the page. Back pops to wherever it
/// was opened from.
class MaraPageFrame extends StatelessWidget {
  const MaraPageFrame({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.onTitle,
    this.titleLabel,
    this.trailing,
  });

  final String title;
  final Widget? subtitle;
  final void Function(Rect? anchor)? onTitle;
  final String? titleLabel;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Ds.void_,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              RoomTitleBar(
                title: title,
                subtitle: subtitle,
                onTitle: onTitle,
                titleLabel: titleLabel,
                trailing: trailing,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      );
}
