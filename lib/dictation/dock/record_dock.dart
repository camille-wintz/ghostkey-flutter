import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/button.dart';
import '../dock_height.dart';
import '../session.dart';
import 'dock_icon_button.dart';
import 'dock_notice.dart';
import 'waveform.dart';

/// The live dictation dock: the state line and clock, the waveform, pause
/// and Done, and whatever the writer must be told. Pinned above the keyboard
/// inset by the flow that shows it. Mirrors the RN RecordOverlay and the
/// desktop RecordPanel.
///
/// No scrim over the page: it keeps its own touches while the session runs,
/// so the writer can scroll back through what they have dictated. Done is
/// the way out.
class RecordDock extends StatefulWidget {
  const RecordDock({super.key, required this.session, required this.onDone});
  final DictationSession session;
  final VoidCallback onDone;

  @override
  State<RecordDock> createState() => _RecordDockState();
}

class _RecordDockState extends State<RecordDock> {
  final _body = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void dispose() {
    dictationDockHeight.value = 0;
    super.dispose();
  }

  void _report() {
    if (!mounted) return;
    final box = _body.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) dictationDockHeight.value = box.size.height;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _report());
        final s = widget.session;
        final notice = s.notice;
        return Container(
          key: _body,
          decoration: BoxDecoration(
            color: Ds.panel,
            border: Border(top: BorderSide(color: Ds.edge)),
          ),
          padding: EdgeInsets.fromLTRB(18, 16, 18, bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _StatusDot(live: s.isRecording),
                  const SizedBox(width: 8),
                  Text(
                    s.isRecording ? 'Listening…' : 'Paused',
                    style: DsStyle.ui(DsText.ui, color: Ds.hi, tracking: 0.4),
                  ),
                  const Spacer(),
                  if (s.isProcessing)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text('Transcribing…', style: DsStyle.ui(DsText.ui, color: Ds.mid)),
                    ),
                  Text(_clock(s.durationMs), style: DsStyle.ui(DsText.ui, color: Ds.mid)),
                ],
              ),
              const SizedBox(height: 14),
              Waveform(levels: s.levels),
              const SizedBox(height: 16),
              Row(
                children: [
                  DockIconButton(
                    icon: s.isRecording ? LucideIcons.pause : LucideIcons.play,
                    label: s.isRecording ? 'Pause' : 'Resume',
                    onPressed: () => s.isRecording ? s.pause() : s.resume(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: GkButton(label: 'Done', wide: true, onPressed: widget.onDone)),
                ],
              ),
              if (notice != null) ...[
                const SizedBox(height: 14),
                DockNoticeView(notice),
              ],
            ],
          ),
        );
      },
    );
  }
}

String _clock(int ms) {
  final total = ms ~/ 1000;
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.live});
  final bool live;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: DsMotion.duration,
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: live ? Ds.accent : Ds.faint,
          boxShadow: live ? [BoxShadow(color: Ds.accentMix(90), blurRadius: 5)] : const [],
        ),
      );
}
