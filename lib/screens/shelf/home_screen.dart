import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../server/providers.dart';
import '../../ui/text.dart';
import '../account/account_screen.dart';
import 'account_pill.dart';
import 'home_backdrop.dart';
import 'shelf_section.dart';
import 'welcome_notices.dart';
import 'welcome_week_strip.dart';

/// Back from the background after this long, the shelf is read again.
const Duration _resumeAfter = Duration(seconds: 30);

/// The shelf: the cloud root drawn as books, a new novel the first of them.
/// Home is where both welcome-week notices belong: it is the first screen
/// after signup and the first after a relaunch.
///
/// The shelf is re-read on a pull, on coming back to the app, and on coming
/// back from a book — the desk adds books this phone has no other way to hear of.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final AppLifecycleListener _lifecycle;
  DateTime? _hiddenAt;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _hiddenAt = DateTime.now(),
      onShow: _onShow,
    );
    // A shelf already read means a book was just closed; a cold start's
    // first read is the one ShelfSection is about to make.
    if (ref.exists(projectsProvider(null))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) refreshShelf(ref);
      });
    }
  }

  void _onShow() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null || DateTime.now().difference(hiddenAt) < _resumeAfter) return;
    refreshShelf(ref);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Ds.void_,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const HomeBackdrop(),
          SafeArea(
            child: RefreshIndicator(
              color: Ds.accent,
              backgroundColor: Ds.panel,
              onRefresh: () => refreshShelf(ref),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
