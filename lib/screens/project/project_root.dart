import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../rooms/rooms.dart';
import '../../ds/tokens.dart';
import '../../server/dto/projects.dart';
import '../../server/errors.dart';
import '../../server/providers.dart';
import '../../store/active_project.dart';
import '../../ui/state_screen.dart';
import '../apparition/apparition_screen.dart';
import '../phantom/phantom_screen.dart';
import '../poltergeist/poltergeist_screen.dart';
import '../veil/veil_screen.dart';
import '../wisp/wisp_screen.dart';
import 'project_home_screen.dart';
import 'project_stage.dart';

/// One open project: a stack whose first screen is the project home (cover,
/// title, rooms) and whose other screens are the rooms themselves. Opening a
/// project lands on the home; no last room is remembered.
///
/// The id is a constructor argument on purpose: the root switch animates
/// this subtree out with the store already empty, and a widget that read the
/// store would spend the slide-out drawing "no project" over a screen the
/// author can still see.
class ProjectRoot extends ConsumerStatefulWidget {
  const ProjectRoot({super.key, required this.projectId, this.preview});
  final String projectId;

  /// The shelf's summary of the book, when it was opened from one. It is
  /// what the book opens on: its cover, title and backdrop, while the full
  /// project loads.
  final ProjectMeta? preview;

  @override
  ConsumerState<ProjectRoot> createState() => _ProjectRootState();
}

class _ProjectRootState extends ConsumerState<ProjectRoot> {
  final _nav = GlobalKey<NavigatorState>();

  void _close() => ref.read(activeProjectProvider.notifier).close();

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider(widget.projectId));

    // Both waiting states are drawn INSTEAD of the project stack, so they
    // answer the back button themselves.
    if (project.isLoading && !project.hasValue) {
      final preview = widget.preview;
      return HardwareBack(
        onBack: _close,
        child: preview != null
            ? ProjectStage(project: preview, onHome: _close, below: const _Opening())
            : StateScreen(spinner: true, message: 'Loading project…', actionLabel: 'Back to Home', onAction: _close),
      );
    }
    if (project.hasError && !project.hasValue) {
      return HardwareBack(
        onBack: _close,
        child: StateScreen(
          message: 'Could not load project.',
          detail: messageFor(project.error),
          actionLabel: 'Try Again',
          onAction: () => ref.invalidate(projectProvider(widget.projectId)),
          secondaryActionLabel: 'Back to Home',
          onSecondaryAction: _close,
        ),
      );
    }

    return ProjectScope(
      projectId: widget.projectId,
      child: HardwareBack(
        onBack: () {
          final nav = _nav.currentState;
          if (nav != null && nav.canPop()) {
            nav.pop();
          } else {
            _close();
          }
        },
        child: Navigator(
          key: _nav,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => switch (settings.name) {
              ApparitionScreen.route => const ApparitionScreen(),
              VeilScreen.route => const VeilScreen(),
              PoltergeistScreen.route => const PoltergeistScreen(),
              PhantomScreen.route => const PhantomScreen(),
              WispScreen.route => const WispScreen(),
              _ => const ProjectHomeScreen(),
            },
          ),
        ),
      ),
    );
  }
}

/// Where the rooms will be: a small light rather than a word, because the book
/// above it already says what is opening.
class _Opening extends StatelessWidget {
  const _Opening();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent, semanticsLabel: 'Opening project'),
          ),
        ),
      );
}

/// The open project's id, for every screen under the project navigator.
class ProjectScope extends InheritedWidget {
  const ProjectScope({super.key, required this.projectId, required super.child});
  final String projectId;

  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProjectScope>()!.projectId;

  @override
  bool updateShouldNotify(ProjectScope oldWidget) => oldWidget.projectId != projectId;
}

/// RoomKey → the project-stack route that hosts the room. The one map.
String routeForRoom(RoomKey key) => switch (key) {
      RoomKey.apparition => ApparitionScreen.route,
      RoomKey.veil => VeilScreen.route,
      RoomKey.poltergeist => PoltergeistScreen.route,
      RoomKey.phantom => PhantomScreen.route,
      RoomKey.wisp => WispScreen.route,
    };
