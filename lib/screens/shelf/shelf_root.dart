import 'package:flutter/material.dart';

import '../../app.dart';
import '../account/account_screen.dart';
import 'home_screen.dart';

/// The signed-in, no-book-open half of the app: the shelf, with Account as
/// an ordinary push under it — that one really is a drill-down an author
/// backs out of.
class ShelfRoot extends StatefulWidget {
  const ShelfRoot({super.key});

  @override
  State<ShelfRoot> createState() => _ShelfRootState();
}

class _ShelfRootState extends State<ShelfRoot> {
  final _nav = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return HardwareBack(
      onBack: () {
        final nav = _nav.currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else {
          exitApp();
        }
      },
      child: Navigator(
        key: _nav,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => switch (settings.name) {
            AccountScreen.route => const AccountScreen(),
            _ => const HomeScreen(),
          },
        ),
      ),
    );
  }
}
