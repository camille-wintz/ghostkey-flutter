import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/session.dart';
import 'ds/tokens.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/project/project_root.dart';
import 'screens/shelf/shelf_root.dart';
import 'store/active_project.dart';

/// The app: one theme, and a root that is exactly one of three things.
class GhostkeyApp extends ConsumerStatefulWidget {
  const GhostkeyApp({super.key});

  @override
  ConsumerState<GhostkeyApp> createState() => _GhostkeyAppState();
}

class _GhostkeyAppState extends ConsumerState<GhostkeyApp> {
  @override
  void initState() {
    super.initState();
    ref.read(sessionProvider.notifier).hydrate();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ghostkey',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Root(),
    );
  }
}

/// Signed out, on the shelf, or inside a book — never two at once.
///
/// Opening a project is a change of MODE, not a drill-down: the open project
/// decides which subtree exists, and nothing navigates between them. The
/// shelf is gone while the book is open, so an author writing in Apparition
/// is not carrying the shelf's queries, covers and animating backdrop.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(sessionProvider.select((s) => s.status));
    final projectId = ref.watch(activeProjectProvider.select((p) => p.projectId));

    final Widget child = switch (status) {
      AuthStatus.hydrating => Container(key: const ValueKey('hydrating'), color: Ds.void_),
      AuthStatus.signedOut => const AuthScreen(key: ValueKey('auth')),
      AuthStatus.signedIn => projectId == null
          ? const ShelfRoot(key: ValueKey('shelf'))
          : ProjectRoot(key: ValueKey('project-$projectId'), projectId: projectId),
    };

    return AnimatedSwitcher(
      duration: DsMotion.screenIn,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
      ),
      child: child,
    );
  }
}

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Ds.void_,
    canvasColor: Ds.void_,
    colorScheme: base.colorScheme.copyWith(
      primary: Ds.accent,
      secondary: Ds.accent,
      surface: Ds.panel,
      error: Ds.destructive,
    ),
    textTheme: base.textTheme.apply(fontFamily: DsFonts.ui, bodyColor: Ds.soft, displayColor: Ds.hi),
    splashFactory: NoSplash.splashFactory,
    highlightColor: const Color(0x00000000),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Ds.accent,
      selectionColor: Ds.accentMix(35),
      selectionHandleColor: Ds.accent,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _SlideInTransitions(),
        TargetPlatform.iOS: _SlideInTransitions(),
      },
    ),
    appBarTheme: AppBarTheme(backgroundColor: Ds.void_, foregroundColor: Ds.hi, elevation: 0),
    dividerColor: Ds.edge,
  );
}

/// The design's own screen transition: a slide on a long ease-out tail.
class _SlideInTransitions extends PageTransitionsBuilder {
  const _SlideInTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
      child: child,
    );
  }
}

/// Answer Android's back button for a root that has nothing to pop.
class HardwareBack extends StatelessWidget {
  const HardwareBack({super.key, required this.onBack, required this.child});
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) onBack();
        },
        child: child,
      );
}

/// Leave the app from a root that has nowhere further back to go.
void exitApp() => SystemNavigator.pop();
