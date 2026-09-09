import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/press.dart';
import '../../ui/sheet.dart';
import 'entity_dossier_pane.dart';
import 'providers.dart';

/// This chapter's people and places: the ones the bible has not filed yet,
/// and the ones it already knows — and, stacked on top of that list,
/// whichever of them the author opened.
///
/// A sheet rather than a screen because the first answer is one tap and the
/// author is mid-sentence — the page stays visible behind it, which is where
/// the names came from. Opening a name stacks *inside* the sheet for the same
/// reason: the way back is one tap to the list they were reading, not out of
/// the room and back in.
///
/// Draws its own header (rather than handing one to the sheet shell) because
/// the header changes with what is stacked.
class NotesNamesSheet extends ConsumerStatefulWidget {
  const NotesNamesSheet({
    super.key,
    required this.projectId,
    required this.filename,
    required this.candidates,
    required this.filing,
    required this.onAccept,
    required this.onDecline,
  });

  final String projectId;

  /// The chapter's filename — what a bible card's `chapters` list holds.
  final String filename;
  final ValueListenable<List<NameCandidate>> candidates;
  final ValueListenable<String?> filing;
  final void Function(NameCandidate candidate) onAccept;
  final void Function(NameCandidate candidate) onDecline;

  /// Opens the sheet over the page.
  static Future<void> show(
    BuildContext context, {
    required String projectId,
    required String filename,
    required ValueListenable<List<NameCandidate>> candidates,
    required ValueListenable<String?> filing,
    required void Function(NameCandidate candidate) onAccept,
    required void Function(NameCandidate candidate) onDecline,
  }) =>
      showGkSheet<void>(
        context,
        // A dossier is a page of prose, not a list of two answers.
        maxHeightFraction: 0.92,
        builder: (context) => NotesNamesSheet(
          projectId: projectId,
          filename: filename,
          candidates: candidates,
          filing: filing,
          onAccept: onAccept,
          onDecline: onDecline,
        ),
      );

  @override
  ConsumerState<NotesNamesSheet> createState() => _NotesNamesSheetState();
}

class _NotesNamesSheetState extends ConsumerState<NotesNamesSheet> {
  BibleEntity? _opened;

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final opened = _opened;
    if (opened != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(eyebrow: opened.type.label, onBack: () => setState(() => _opened = null), onClose: _close),
          Flexible(
            child: EntityDossierPane(key: ValueKey(opened.key), projectId: widget.projectId, entity: opened),
          ),
        ],
      );
    }

    // Who this chapter is already known to be about. A card's `chapters` are
    // filenames, which is exactly what the store holds as the active chapter.
    final cast = (ref.watch(bibleProvider(widget.projectId)).value?.entities ?? const <BibleEntity>[])
        .where((e) => !e.hidden && e.chapters.contains(widget.filename))
        .toList();

    return ValueListenableBuilder<List<NameCandidate>>(
      valueListenable: widget.candidates,
      builder: (context, candidates, _) {
        // Nothing to file is the ordinary case — a chapter is swept once and
        // then stays swept — so the sweep's half of the sheet is absent rather
        // than reporting its own emptiness, and the cast becomes what the
        // sheet is titled.
        final hasCandidates = candidates.isNotEmpty;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                SheetHeader(
                  eyebrow: hasCandidates ? 'New names' : 'In this chapter',
                  trailing: '${hasCandidates ? candidates.length : cast.length}',
                  onClose: _close,
                ),
                Positioned(
                  right: 68,
                  top: 14,
                  child: ValueListenableBuilder<String?>(
                    valueListenable: widget.filing,
                    builder: (context, filing, _) => filing == null
                        ? const SizedBox.shrink()
                        : SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent)),
                  ),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasCandidates)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ValueListenableBuilder<String?>(
                          valueListenable: widget.filing,
                          builder: (context, filing, _) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final c in candidates)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _CandidateCard(
                                    candidate: c,
                                    busy: filing == c.name,
                                    onAccept: () => widget.onAccept(c),
                                    onDecline: () => widget.onDecline(c),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    Container(
                      margin: hasCandidates ? const EdgeInsets.only(top: 10) : null,
                      decoration: hasCandidates ? BoxDecoration(border: Border(top: BorderSide(color: Ds.edge))) : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // The cast's own heading, only when the sweep's section
                          // is above it to be told apart from — otherwise the
                          // sheet's title is it.
                          if (hasCandidates)
                            SizedBox(
                              height: DsGeom.row,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  children: [
                                    Expanded(child: Text('IN THIS CHAPTER', style: DsStyle.eyebrow())),
                                    Text('${cast.length}', style: DsStyle.ui(DsText.eyebrow, color: Ds.mid, tracking: DsTracking.pill)),
                                  ],
                                ),
                              ),
                            ),
                          for (final entity in cast)
                            _CastRow(entity: entity, onOpen: () => setState(() => _opened = entity)),
                          if (cast.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: Text('Nobody the bible knows, yet.', style: DsStyle.ui(DsText.ui, color: Ds.low)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate, required this.busy, required this.onAccept, required this.onDecline});
  final NameCandidate candidate;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: busy ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: Ds.edge),
            borderRadius: BorderRadius.circular(DsGeom.radius),
            color: Ds.surf,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: Text(candidate.name, style: DsStyle.ui(DsText.body, color: Ds.hi, weight: FontWeight.w600))),
                  const SizedBox(width: 10),
                  Text(candidate.type.label.toUpperCase(), style: DsStyle.eyebrow()),
                ],
              ),
              // The chapter's own words, in the chapter's own face — this is
              // the one place outside the page where Spectral is honest,
              // because it IS the page, quoted.
              if (candidate.note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  candidate.note,
                  style: TextStyle(
                    fontFamily: DsFonts.manuscript,
                    fontStyle: FontStyle.italic,
                    fontSize: DsText.body.size,
                    height: 22 / DsText.body.size,
                    color: Ds.mid,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _CardButton(
                      icon: LucideIcons.check,
                      label: 'Add',
                      semanticLabel: 'Add ${candidate.name} to the world bible',
                      accent: true,
                      enabled: !busy,
                      onPressed: onAccept,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CardButton(
                      icon: LucideIcons.x,
                      label: 'Not one',
                      semanticLabel: '${candidate.name} is not an entity',
                      accent: false,
                      enabled: !busy,
                      onPressed: onDecline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.accent,
    required this.enabled,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final String semanticLabel;
  final bool accent;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ink = accent ? Ds.accent : Ds.soft;
    return Press(
      onPressed: onPressed,
      enabled: enabled,
      semanticLabel: semanticLabel,
      builder: (context, pressed) => Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DsGeom.radius),
          border: Border.all(
            color: accent ? (pressed ? Ds.accent : Ds.accentMix(55)) : Ds.edgeHi,
          ),
          color: accent
              ? Ds.accentMix(pressed ? 20 : 12)
              : pressed
                  ? Ds.veil
                  : const Color(0x00000000),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: ink),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: DsStyle.ui(DsText.ui, color: ink, weight: FontWeight.w600, tracking: DsTracking.control),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the chapter's known names, and the way into what the book knows
/// about it. A row rather than a chip: a chip reads as a label, and this one
/// opens something.
class _CastRow extends StatelessWidget {
  const _CastRow({required this.entity, required this.onOpen});
  final BibleEntity entity;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onOpen,
        semanticLabel: 'Open ${entity.name}',
        builder: (context, pressed) => Container(
          height: DsGeom.row,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          color: pressed ? Ds.veil : const Color(0x00000000),
          child: Row(
            children: [
              Expanded(
                child: Text(entity.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsStyle.ui(DsText.body, color: Ds.soft)),
              ),
              const SizedBox(width: 10),
              Text(
                entity.type.label.toUpperCase(),
                style: TextStyle(fontFamily: DsFonts.ui, fontSize: 10, letterSpacing: DsTracking.pill, color: Ds.low),
              ),
              const SizedBox(width: 10),
              Icon(LucideIcons.chevronRight, size: 15, color: Ds.faint),
            ],
          ),
        ),
      );
}
