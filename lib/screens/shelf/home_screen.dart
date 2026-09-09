import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../server/errors.dart';
import '../../server/projects/api.dart';
import '../../server/providers.dart';
import '../../store/active_project.dart';
import '../../ui/text.dart';
import '../account/account_screen.dart';
import 'account_pill.dart';
import 'create_panel.dart';
import 'docx_import.dart';
import 'home_backdrop.dart';
import 'shelf_section.dart';
import 'welcome_notices.dart';
import 'welcome_week_strip.dart';

/// The shelf: "+ New project" and the cloud root, drawn as books. Home is
/// where both welcome-week notices belong: it is the first screen after
/// signup and the first after a relaunch.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _name = TextEditingController();
  bool _creating = false;
  bool _importing = false;
  String? _importStatus;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _name.text.trim();
    if (title.isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      final project = await createProject(name: slugifyProjectName(title), title: title, starterChapter: true);
      ref.invalidate(projectsProvider);
      _name.clear();
      // No navigate: the open project is what decides whether the shelf or
      // the book is mounted at the root.
      ref.read(activeProjectProvider.notifier).open(project.id);
    } catch (e) {
      if (mounted) _say('Could not create', messageFor(e));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  /// A Word document from a desk becomes a project of its own. The flow —
  /// pick, create, upload, follow the job — lives in docx_import.dart; what
  /// belongs here is only the screen's own state and where it lands.
  Future<void> _import() async {
    if (_importing || _creating) return;
    setState(() {
      _importing = true;
      _importStatus = null;
    });
    try {
      final result = await importDocxAsProject(
        onProgress: (line) {
          if (mounted) setState(() => _importStatus = line);
        },
        isAlive: () => mounted,
      );
      if (!mounted) return;
      switch (result) {
        case DocxImportCancelled():
          break;
        case DocxImportFailed(message: final message):
          _say('Could not import', message);
        case DocxImportDone(project: final project, chapters: final chapters):
          ref.invalidate(projectsProvider);
          _name.clear();
          if (chapters != null && chapters > 0) {
            _importStatus = '$chapters ${chapters == 1 ? 'chapter' : 'chapters'} imported.';
          }
          ref.read(activeProjectProvider.notifier).open(project.id);
      }
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _importStatus = null;
        });
      }
    }
  }

  void _say(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
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
                        BrandTitle('GhostKey.AI', align: TextAlign.center),
                        SizedBox(height: 10),
                        _Tagline(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const WelcomeWeekStrip(),
                        CreatePanel(
                          name: _name,
                          onCreate: _create,
                          creating: _creating,
                          onImport: _import,
                          importing: _importing,
                          importStatus: _importStatus,
                        ),
                      ],
                    ),
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
      UiText('Create a new project or open one from the cloud.', color: Ds.mid, align: TextAlign.center);
}
