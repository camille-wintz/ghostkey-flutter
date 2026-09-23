import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/text.dart';
import '../account/account_screen.dart';
import 'account_pill.dart';
import 'home_backdrop.dart';
import 'shelf_section.dart';
import 'welcome_notices.dart';
import 'welcome_week_strip.dart';

/// The shelf: the cloud root drawn as books, a new novel the first of them.
/// Home is where both welcome-week notices belong: it is the first screen
/// after signup and the first after a relaunch.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Ds.void_,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const HomeBackdrop(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 52,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AccountPill(
                          onPressed: () => Navigator.of(context).pushNamed(AccountScreen.route),
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: Column(
                      children: [
                        BrandTitle('Ghostkey', align: TextAlign.center),
                        SizedBox(height: 10),
                        _Tagline(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
                    child: const WelcomeWeekStrip(),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 30, 16, 0),
                    child: ShelfSection(),
                  ),
                ],
              ),
            ),
          ),
          const WelcomeNotices(),
        ],
      ),
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) =>
      UiText('Start a novel, or open one you have.', color: Ds.mid, align: TextAlign.center);
}
