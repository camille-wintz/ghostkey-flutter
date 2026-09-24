import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../access/capability.dart';
import '../../../autosave/field_autosave.dart';
import '../../../core/words.dart';
import '../../../ds/tokens.dart';
import '../../../mara/access.dart';
import '../../../mara/chapter_plan.dart';
import '../../../mara/outline_text.dart';
import '../../../mara/pages.dart';
import '../../../mara/providers.dart';
import '../../../mara/runs.dart';
import '../../../server/dto/plan.dart';
import '../../../server/dto/projects.dart';
import '../../../server/jobs/job_run.dart';
import '../../../server/providers.dart';
import '../../../ui/button.dart';
import '../../../ui/confirm_sheet.dart';
import '../../../ui/job_running.dart';
import '../../../ui/lock_notice.dart';
import '../../../ui/menu_sheet.dart';
import '../../../ui/page_footer.dart';
import '../../../ui/page_notice.dart';
import '../../../ui/room_bar_action.dart';
import '../../../ui/room_subtitle.dart';
import '../dismiss_proposal.dart';
import '../mara_page_frame.dart';
import '../mara_page_screen.dart';
import '../plan_in_chat.dart';
import '../proposal_ledge.dart';
import 'outline_editor.dart';

/// The Outline page once the row is in: the editor, the proposal waiting on
/// the Chapters page, the fill from the book, and the break into chapters.
class OutlinePageBody extends ConsumerStatefulWidget {
  const OutlinePageBody({super.key, required this.projectId, required this.initial});
  final String projectId;
  final String initial;

  @override
  ConsumerState<OutlinePageBody> createState() => _OutlinePageBodyState();
}

class _OutlinePageBodyState extends ConsumerState<OutlinePageBody> {
  late final FieldAutosave _autosave =
      outlineAutosave(ProviderScope.containerOf(context, listen: false), widget.projectId, widget.initial);

  String get _projectId => widget.projectId;

  @override
  void dispose() {
    _autosave.dispose();
    super.dispose();
  }

  Future<void> _fill() async {
    final gate = ref.read(capabilityProvider(outlineSketchCapability));
    if (!gate.granted) return explainLock(context, gate, 'Outline from the book');
    final replace = _autosave.text.text.trim().isNotEmpty;
    if (replace) {
      final ok = await showConfirmSheet(
        context,
        eyebrow: 'Fill from the book',
        title: 'Replace your outline?',
        message: "This reads the book and writes a fresh outline over the one in the editor. What you've written there now is not kept anywhere else.",
        confirmLabel: 'Replace it',
        cancelLabel: 'Keep mine',
        destructive: true,
      );
      if (!ok) return;
    }
    await ref.read(outlineSketchRunProvider(_projectId).notifier).sketch(replace: replace);
  }

  Future<void> _menu({required bool hasChapters, required bool running}) async {
    final granted = ref.read(capabilityProvider(outlineSketchCapability)).granted;
    final picked = await showMenuSheet<bool>(
      context,
      title: 'Outline',
      entries: [
        MenuEntry(
          icon: granted ? LucideIcons.bookOpen : LucideIcons.lock,
          label: 'Fill from the book',
          value: true,
          enabled: hasChapters && !running,
        ),
      ],
    );
    if (picked == true && mounted) await _fill();
  }

  @override
  Widget build(BuildContext context) {
    // A fill that lands wrote the outline server-side; it replaces the
    // editor's text, which is the one time the page takes the server's.
    ref.listen<JobRunState>(outlineSketchRunProvider(_projectId), (prev, next) {
      if (prev?.running != true || next.running || next.error != null) return;
      ref.read(authoredOutlineProvider(_projectId).future).then((o) {
        if (mounted) _autosave.reset(o.text);
      }).catchError((Object _) {});
    });

    final project = ref.watch(projectProvider(_projectId)).value;
    final hasChapters = project != null && chaptersInTree(project.chapters).isNotEmpty;
    final outline = ref.watch(authoredOutlineProvider(_projectId)).value;
    final dismissing = ref.watch(chapterPlanWritesProvider(_projectId).select((s) => s.dismissing));
    final run = ref.watch(outlineSketchRunProvider(_projectId));
    final pending = outline?.pending ?? false;
    // A proposal read from this prose would be voided by editing it, so the
    // prose holds still until it is reviewed or dismissed.
    final madeHere = pending && (outline?.brokenFrom.isProse ?? false);

    return MaraPageFrame(
      title: 'Outline',
      subtitle: project == null ? null : RoomSubtitle(project.project.displayTitle),
      trailing: RoomBarAction(
        icon: LucideIcons.ellipsis,
        semanticLabel: 'Outline',
        onPressed: () => _menu(hasChapters: hasChapters, running: run.running),
      ),
      child: Column(
        children: [
          if (outline != null && pending)
            ProposalLedge(
              count: outline.changeset?.ops.length ?? proposalChapters(outline.chapters).length,
              changeset: outline.changeset != null,
              madeFrom: madeHere ? 'this outline' : null,
              consequence: madeHere ? 'The outline is read-only until you review or dismiss them.' : null,
              dismissing: dismissing,
              onReview: () => openMaraPage(context, MaraPage.chapters),
              onDismiss: () => dismissProposal(context, ref, _projectId, changeset: outline.changeset != null),
            ),
          if (run.error case final error? when !run.running)
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: PageNotice(error, error: true)),
          Expanded(
            child: OutlineEditor(
              autosave: _autosave,
              readOnly: madeHere || run.running,
              readOnlyNote: run.running ? 'Being written from the book…' : 'Read-only while chapters are proposed',
            ),
          ),
          PageFooter(
            child: ListenableBuilder(
              listenable: _autosave.text,
              builder: (context, _) {
                final words = countWords(_autosave.text.text);
                final status = run.running
                    ? jobProgressLine(run.progress, 'Reading the book')
                    : '${formatWords(words)} ${words == 1 ? 'word' : 'words'} · '
                        '${outline?.committedDraftId != null ? 'Broken into chapters' : 'Not broken into chapters yet'}';
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DsStyle.ui(DsText.ui, color: run.running ? Ds.accent300 : Ds.low),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GkButton(
                      label: 'Break into chapters',
                      disabled: words == 0 || run.running,
                      onPressed: () => planChaptersInChat(
                        context,
                        ref,
                        projectId: _projectId,
                        title: 'Chapters from the outline',
                        ask: 'Plan the chapters from my outline.',
                        flush: _autosave.flush,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
