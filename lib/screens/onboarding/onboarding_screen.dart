// Flutter's own `Intent` (Actions/Shortcuts) collides with the author's, and
// this screen wants the author's.
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../server/dto/profile.dart';
import '../../server/dto/projects.dart';
import '../../server/errors.dart';
import '../../server/profile/api.dart';
import '../../server/projects/api.dart';
import '../../server/providers.dart';
import '../../store/active_project.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';
import '../shelf/docx_import.dart';
import 'intents.dart';
import 'seed_prompt.dart';

// The first-run flow on a phone: four questions, and the project they make.
//
// Same questions and the same stored answers as the desk, and deliberately not
// the same endings — the phone has no Mara and no Glamour, so `plot` ends in
// the chat and `pitch` is not offered at all (see intents.dart).
//
// Every answer PUTs as it is given rather than at the end: an author who puts
// the phone down after the first question still leaves behind the one fact the
// backoffice most wants, which is that they said they didn't know where to
// start.

enum _Step { experience, start, title, intent }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Step _step = _Step.experience;
  final _title = TextEditingController();
  ProjectMeta? _imported;
  bool _busy = false;
  String? _error;
  String? _status;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _to(_Step step) => setState(() {
        _step = step;
        _error = null;
      });

  /// A save that fails must not strand the author on a question they have
  /// already answered — the flow carries on and the row catches up on the next
  /// answer, or stays as it is. Nothing reads a mid-flow answer, so this
  /// deliberately does not touch the cached profile: the only read that matters
  /// is the root's, and it is refreshed once, at the end.
  Future<void> _remember(Future<AuthorProfile> Function() save) async {
    try {
      await save();
    } catch (_) {
      // Nothing to tell the author: they answered a question, and keeping the
      // answer is ours to do, not theirs to retry.
    }
  }

  /// Leave the flow into the book it made.
  ///
  /// The refresh is not optional. `_Root` only asks whether the flow is owed
  /// while no project is open, and it asks the CACHED profile — so a flow that
  /// opened a book without refreshing would come back the moment the author
  /// closed it, having already been answered.
  void _land(ProjectMeta project, {Intent? mark, String? ask}) {
    ref.invalidate(authorProfileProvider);
    ref.read(activeProjectProvider.notifier).open(project.id, mark: mark, ask: ask);
  }

  Future<void> _guided() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // The chat is project-scoped, so there has to be a book before there can
      // be a conversation. Named by nobody yet — this author does not know what
      // the book is, which is the whole reason they are on this branch.
      final project = await createProject(name: defaultTitle, title: defaultTitle);
      await _remember(() => saveAuthorProfile(
            experience: Experience.beginner,
            intent: Intent.guided,
            firstProjectId: project.id,
            completed: true,
          ));
      if (!mounted) return;
      _land(project, ask: seedPrompt());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = messageFor(e);
      });
    }
  }

  Future<void> _pick(IntentOption option) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final project = _imported ??
          await createProject(
            name: _title.text.trim().isEmpty ? defaultTitle : _title.text.trim(),
            title: _title.text.trim().isEmpty ? defaultTitle : _title.text.trim(),
            starterChapter: true,
          );
      if (option.opensChat) {
        await _remember(() => saveAuthorProfile(
              intent: option.intent,
              firstProjectId: project.id,
              completed: true,
            ));
        if (!mounted) return;
        // No seeded question: this is an experienced writer who chose to plot,
        // and the guided branch's "I don't know where to start" would be words
        // put in their mouth. The chat's own intro offers planning openers.
        _land(project);
        return;
      }
      await _remember(() => saveAuthorProfile(
            intent: option.intent,
            firstProjectId: project.id,
            completed: true,
          ));
      if (!mounted) return;
      _land(project, mark: option.intent);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = messageFor(e);
      });
    }
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    final result = await importDocxAsProject(
      onProgress: (line) {
        if (mounted) setState(() => _status = line);
      },
      isAlive: () => mounted,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = null;
    });
    switch (result) {
      // Closing the picker leaves them on the question they were on, which is
      // where they were.
      case DocxImportCancelled():
        return;
      case DocxImportFailed(:final message):
        setState(() => _error = message);
      case DocxImportDone(:final project):
        _imported = project;
        await _remember(() => saveAuthorProfile(startMode: StartMode.import));
        if (mounted) _to(_Step.intent);
    }
  }

  Future<void> _skip() async {
    setState(() => _busy = true);
    await _remember(() => saveAuthorProfile(skipped: true));
    if (!mounted) return;
    ref.invalidate(authorProfileProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Ds.void_,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._body(),
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  UiText(_status!, step: DsText.ui, color: Ds.low, align: TextAlign.center),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  UiText(_error!, step: DsText.ui, color: Ds.destructive, align: TextAlign.center),
                ],
                const SizedBox(height: 24),
                Center(
                  child: Press(
                    onPressed: _busy ? null : _skip,
                    semanticLabel: 'Skip these questions',
                    builder: (context, pressed) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      child: Text(
                        'Skip this',
                        style: DsStyle.eyebrow(color: pressed ? Ds.mid : Ds.low),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body() => switch (_step) {
        _Step.experience => [
            const _Question(
              eyebrow: 'First, so we start in the right place',
              title: 'How much of this have you done before?',
            ),
            _Choice(
              label: "I've written before",
              blurb: "You know your process. We'll open the right room and get out of the way.",
              disabled: _busy,
              onPressed: () {
                _remember(() => saveAuthorProfile(experience: Experience.experienced));
                _to(_Step.start);
              },
            ),
            _Choice(
              label: "I don't know where to start",
              blurb: "We'll talk it through — the idea, the genre, and whether to plot or just write.",
              disabled: _busy,
              onPressed: _guided,
            ),
          ],
        _Step.start => [
            const _Question(
              eyebrow: 'Your first book here',
              title: 'Do you have a manuscript already?',
            ),
            _Choice(
              label: 'Import a .docx',
              blurb: 'Your chapters come across as chapters, ready to work on.',
              disabled: _busy,
              onPressed: _import,
            ),
            _Choice(
              label: 'Start something new',
              blurb: 'An empty book with a first chapter to type into.',
              disabled: _busy,
              onPressed: () {
                _remember(() => saveAuthorProfile(startMode: StartMode.newBook));
                _to(_Step.title);
              },
            ),
          ],
        _Step.title => [
            const _Question(
              eyebrow: 'It can change later',
              title: 'Does it have a title yet?',
            ),
            GkField(
              controller: _title,
              placeholder: 'Working title…',
              autofocus: true,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _to(_Step.intent),
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: _title,
              builder: (context, _) => GkButton(
                label: _title.text.trim().isEmpty ? 'Skip' : 'Next',
                wide: true,
                disabled: _busy,
                onPressed: () => _to(_Step.intent),
              ),
            ),
          ],
        _Step.intent => [
            const _Question(
              eyebrow: "We'll open it for you",
              title: 'What do you want to do first?',
            ),
            for (final option in intentOptions())
              _Choice(
                label: option.label,
                blurb: option.blurb,
                disabled: _busy,
                onPressed: () => _pick(option),
              ),
          ],
      };
}

class _Question extends StatelessWidget {
  const _Question({required this.eyebrow, required this.title});
  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          children: [
            Eyebrow(eyebrow, color: Ds.accent),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: DsStyle.prose(DsText.title, weight: FontWeight.w600),
            ),
          ],
        ),
      );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.blurb,
    required this.onPressed,
    this.disabled = false,
  });
  final String label;
  final String blurb;
  final VoidCallback onPressed;
  final bool disabled;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Press(
          onPressed: disabled ? null : onPressed,
          semanticLabel: label,
          builder: (context, pressed) => Opacity(
            opacity: disabled ? 0.45 : 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pressed ? Ds.veil : Ds.panel,
                border: Border.all(color: pressed ? Ds.accent : Ds.edge),
                borderRadius: BorderRadius.circular(DsGeom.radius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: DsStyle.ui(const DsStep(17, 23), color: Ds.hi, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  UiText(blurb, color: Ds.mid),
                ],
              ),
            ),
          ),
        ),
      );
}
