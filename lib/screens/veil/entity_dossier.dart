import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../access/capability.dart';
import '../../access/plans.dart';
import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/button.dart';
import '../../ui/confirm_sheet.dart';
import '../../veil/dossier_build.dart';
import '../../veil/providers.dart';
import '../../veil/roster.dart';
import 'dossier_body.dart';
import 'veil_section.dart';
import 'veil_section_link.dart';

/// The entity's dossier: the card's own markdown text ([BibleEntity.notes]),
/// which the author edits and the `entity_dossier` job writes, plus the
/// generated half (stale notice, timeline, provenance) cached until a chapter
/// that mentions it changes. Cards carry no facts — this IS the entity's info
/// surface — so opening the page builds a missing dossier on its own (the job
/// fills an empty text).
///
/// Two modes, as on the desk. READING, the text is set as prose and nothing
/// changes it; an empty dossier offers the two ways in — Fill from the book,
/// and Create dossier, which opens edit mode on the text. EDITING, the text
/// is not drawn: one button opens it on its own screen
/// (`DossierEditorScreen`), the interview files answers into it, and one run
/// is on offer: the fill for an empty text, the Update for a stale one, and
/// the Refresh that replaces the author's text after a warning. The phone
/// web's `EntityDossier.tsx` is the same band.
class EntityDossier extends ConsumerStatefulWidget {
  const EntityDossier({
    super.key,
    required this.projectId,
    required this.entity,
    required this.dossier,
    required this.hasChapters,
    required this.editing,
    required this.onEdit,
    required this.onCreate,
    required this.onInterview,
  });

  final String projectId;
  final BibleEntity entity;
  final Dossier? dossier;
  final bool hasChapters;

  /// The page is in edit mode.
  final bool editing;

  /// Opens the dossier text's own screen.
  final VoidCallback onEdit;

  /// Starts a dossier by hand from the reading page: edit mode, then the text.
  final VoidCallback onCreate;

  /// Opens the interview.
  final VoidCallback onInterview;

  @override
  ConsumerState<EntityDossier> createState() => _EntityDossierState();
}

class _EntityDossierState extends ConsumerState<EntityDossier> {
  DossierTarget get _target => (projectId: widget.projectId, key: widget.entity.key);

  @override
  void initState() {
    super.initState();
    // After the first build, so the provider is being watched (and so kept
    // alive) by the time its notifier starts polling.
    Future<void>.microtask(() {
      if (mounted) unawaited(ref.read(dossierBuildProvider(_target).notifier).buildOnOpen());
    });
  }

  void _start({bool force = false, bool fill = false}) =>
      unawaited(ref.read(dossierBuildProvider(_target).notifier).start(force: force, fill: fill));

  /// Replacing the author's text is the one run that loses their words, so
  /// it asks first.
  Future<void> _refresh() async {
    final ok = await showConfirmSheet(
      context,
      eyebrow: 'Dossier',
      title: 'Replace the dossier?',
      message: 'This writes a fresh dossier from the book. Your own changes to it will be lost.',
      confirmLabel: 'Replace',
      destructive: true,
    );
    if (ok && mounted) _start(force: true, fill: true);
  }

  @override
  Widget build(BuildContext context) {
    final build = ref.watch(dossierBuildProvider(_target));
    final probed = ref.watch(dossiersProvider(widget.projectId)).hasValue;
    final capability = ref.watch(capabilityProvider(dossierCapability));
    final dossier = widget.dossier;
    final hasText = widget.entity.notes.trim().isNotEmpty;
    final canRun = capability.granted && widget.entity.mentionCount > 0 && widget.hasChapters;

    // The one run on offer once nothing is in flight.
    final Widget? action = !canRun || build.building || build.error != null
        ? null
        : !hasText
            ? (dossier == null
                ? null // the build-on-open is already doing it
                // A cached dossier is a cache hit without force, and a cache
                // hit files no prose.
                : VeilSectionLink(icon: LucideIcons.sparkles, label: 'Fill from the book', onTap: () => _start(force: true)))
            : dossier != null && dossier.stale
                // Keeps the author's text; refreshes the timeline and the rest.
                ? VeilSectionLink(icon: LucideIcons.refreshCw, label: 'Update', onTap: _start)
                : VeilSectionLink(icon: LucideIcons.refreshCw, label: 'Refresh from the book', onTap: _refresh);

    final editing = widget.editing;
    return VeilSection(
      title: 'Dossier',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (build.building) ...[
            _Working(build.progress),
            if (!editing && hasText) const SizedBox(height: 16),
          ] else if (build.error case final String error) ...[
            _Failed(error, canRun ? () => _start() : null),
            const SizedBox(height: 16),
          ] else if (!editing && !hasText && dossier == null)
            Text(
              !probed
                  ? 'Checking for a dossier…'
                  : canRun
                      ? 'Reading the mentions…'
                      : _whyNot(capability),
              style: DsStyle.ui(DsText.ui, color: Ds.faint),
            ),
          if (editing) ...[
            if (!build.building) ...[
              if (dossier != null && dossier.stale && hasText) const DossierStaleNotice(editing: true),
              Align(
                alignment: Alignment.centerLeft,
                child: GkButton(
                  label: hasText ? 'Edit dossier' : 'Write the dossier',
                  leading: Icon(LucideIcons.penLine, size: 16, color: Ds.accent),
                  onPressed: widget.onEdit,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: GkButton(
                  label: 'Answer questions',
                  variant: ButtonVariant.outline,
                  leading: Icon(LucideIcons.messagesSquare, size: 16, color: Ds.soft),
                  onPressed: widget.onInterview,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: action),
              ],
            ],
          ] else if (hasText)
            DossierBody(notes: widget.entity.notes, dossier: dossier)
          else if (!build.building)
            _Empty(
              name: titleCase(widget.entity.name),
              // Filling needs a reading to file from; without one the
              // build-on-open is the fill.
              onFill: canRun && dossier != null && build.error == null ? () => _start(force: true) : null,
              onCreate: widget.onCreate,
              spaced: dossier == null,
            ),
        ],
      ),
    );
  }

  /// Why nothing will be built: the server's own checks, in its order.
  String _whyNot(CapabilityState capability) {
    if (!capability.granted) {
      final plan = capability.requiredPlan != null ? planName(capability.requiredPlan!) : 'a higher plan';
      return 'Writing a dossier is part of $plan. One already written reads on any plan.';
    }
    if (widget.entity.mentionCount == 0) {
      return 'No manuscript mentions to draw from yet — the dossier is written from the passages around each mention.';
    }
    return 'Needs a manuscript with chapters.';
  }
}

class _Working extends StatelessWidget {
  const _Working(this.progress);
  final String? progress;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent)),
          const SizedBox(width: 10),
          Expanded(child: Text(progress ?? 'Reading the mentions…', style: DsStyle.ui(DsText.ui, color: Ds.mid))),
        ],
      );
}

class _Failed extends StatelessWidget {
  const _Failed(this.error, this.onRetry);
  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error, style: DsStyle.ui(DsText.ui, color: Ds.destructive)),
          if (onRetry != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GkButton(label: 'Retry the dossier', variant: ButtonVariant.outline, onPressed: onRetry),
            ),
        ],
      );
}

/// A card with nothing written about it yet, as the reading page shows it:
/// the two ways a dossier starts, side by side — read from the book, or
/// written by the author (edit mode, where the interview is).
class _Empty extends StatelessWidget {
  const _Empty({required this.name, required this.onFill, required this.onCreate, required this.spaced});
  final String name;
  final VoidCallback? onFill;
  final VoidCallback onCreate;

  /// A status line sits above it.
  final bool spaced;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: spaced ? 16 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!spaced) ...[
              Text('Nothing written about $name yet.', style: DsStyle.prose(DsText.body, color: Ds.mid)),
              const SizedBox(height: 14),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onFill case final onFill?)
                  GkButton(
                    label: 'Fill from the book',
                    leading: Icon(LucideIcons.bookOpenText, size: 16, color: Ds.accent),
                    onPressed: onFill,
                  ),
                GkButton(
                  label: 'Create dossier',
                  variant: ButtonVariant.outline,
                  leading: Icon(LucideIcons.penLine, size: 16, color: Ds.soft),
                  onPressed: onCreate,
                ),
              ],
            ),
          ],
        ),
      );
}
