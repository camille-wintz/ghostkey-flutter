import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../access/capability.dart';
import '../../core/words.dart';
import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';
import '../../ui/button.dart';
import '../../ui/lock_notice.dart';
import '../../wisp/access.dart';
import '../../wisp/preview_filler.dart';
import 'report_card.dart';

/// Under the part of a report a preview shows: stand-in text the size of the
/// rest, blurred and fading out, with the way to the whole one on top. The
/// words under the blur are filler — the server never sent the real ones.
class ReportPreview extends ConsumerWidget {
  const ReportPreview({super.key, required this.cut, required this.subject});
  final PreviewCut cut;

  /// What the whole thing is called: "outline", "synopsis", "report".
  final String subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(capabilityProvider(fullReportsCapability));
    final filler = previewFiller(cut);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Stack(
        children: [
          ExcludeSemantics(
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                stops: [0.35, 1],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: ReportCard(
                  child: ConstrainedBox(
                    // Room for the card on top however little is held back.
                    constraints: const BoxConstraints(minHeight: 220, minWidth: double.infinity),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final para in filler)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(para, style: DsStyle.prose(DsText.body, color: Ds.low)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 28,
            child: ReportCard(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                children: [
                  Text(
                    cut.hiddenWords < 100
                        ? 'The rest is written and kept for you.'
                        : 'About ${formatWords(cut.hiddenWords)} more words are written and kept for you.',
                    textAlign: TextAlign.center,
                    style: DsStyle.ui(DsText.body, color: Ds.mid),
                  ),
                  const SizedBox(height: 14),
                  GkButton(
                    label: 'See the whole $subject',
                    onPressed: () => explainLock(context, gate, fullReportsLabel),
                    leading: Icon(LucideIcons.lock, size: 14, color: Ds.accent),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
