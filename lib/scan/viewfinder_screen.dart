import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../ds/tokens.dart';
import '../server/errors.dart';
import '../ui/press.dart';
import '../ui/state_screen.dart';
import 'camera_session.dart';
import 'fit_image.dart';
import 'focus_ring.dart';
import 'page_brackets.dart';
import 'viewfinder_geometry.dart';

// What we send up for OCR. Vision models downsample anything larger before
// they read it, so extra pixels buy no accuracy — only upload time, and past
// the server's payload cap a 413. ~1.15 MP / 1568px on the long edge is where
// the gain stops; a 12 MP phone photo lands ~30× smaller.
const FitOptions ocrImageBudget = FitOptions(maxEdge: 1568, maxPixels: 1150000, quality: 0.8);

/// The in-app camera: top bar (close, title, flash), the preview under the
/// page brackets with tap-to-focus, and the shutter row (library pick,
/// shutter, exposure lock). A capture or a pick is fitted to the OCR budget
/// here, so the shutter's busy state covers the whole wait.
class ViewfinderScreen extends StatefulWidget {
  const ViewfinderScreen({super.key, required this.onCaptured, required this.onClose});
  final ValueChanged<EncodedImage> onCaptured;
  final VoidCallback onClose;

  @override
  State<ViewfinderScreen> createState() => _ViewfinderScreenState();
}

class _ViewfinderScreenState extends State<ViewfinderScreen> {
  final _session = CameraSession();
  final _picker = ImagePicker();
  bool _fitting = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSession);
    _session.start();
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _session.dispose();
    super.dispose();
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  bool get _busy => _fitting || _session.capturing;

  Future<void> _shoot() async {
    if (_busy) return;
    final bytes = await _session.capture();
    if (bytes == null) return;
    await _hand(bytes);
  }

  Future<void> _pick() async {
    if (_busy) return;
    final file = await _picker.pickImage(source: ImageSource.gallery, requestFullMetadata: false);
    if (file == null) return;
    await _hand(await file.readAsBytes());
  }

  Future<void> _hand(Uint8List bytes) async {
    setState(() {
      _fitting = true;
      _problem = null;
    });
    try {
      final image = await fitImage(bytes, ocrImageBudget);
      if (!mounted) return;
      widget.onCaptured(image);
    } catch (e) {
      if (!mounted) return;
      setState(() => _problem = messageFor(e));
    } finally {
      if (mounted) setState(() => _fitting = false);
    }
  }

  void _tap(Size box, Offset local) {
    final content = _session.previewSize;
    if (content == null) return;
    final normalized = normalizeIn(coverRect(box, content), local);
    if (normalized == null) return;
    _session.focusAt(normalized: normalized, mark: local);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _session.phase == CameraPhase.ready;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      color: Ds.void_,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              flashOn: _session.flash != FlashMode.off,
              onClose: widget.onClose,
              onFlash: _session.toggleFlash,
            ),
            Expanded(
              child: ClipRect(
                child: ColoredBox(
                  color: Ds.void_,
                  child: _viewfinder(),
                ),
              ),
            ),
            // The row is the last thing on screen, so under Android's
            // edge-to-edge it lands beneath the system nav bar: pad by the
            // inset and grow by the same amount, or the shutter loses height.
            Container(
              height: 116 + bottomInset,
              padding: EdgeInsets.only(left: 34, right: 34, bottom: bottomInset),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SquareControl(
                    icon: LucideIcons.images,
                    label: 'Choose from library',
                    onPressed: _busy ? null : _pick,
                  ),
                  _Shutter(enabled: ready && !_busy, busy: _busy, onPressed: _shoot),
                  _SquareControl(
                    icon: LucideIcons.sunMedium,
                    label: _session.exposureLocked ? 'Unlock exposure' : 'Lock exposure',
                    active: _session.exposureLocked,
                    onPressed: ready ? _session.toggleExposureLock : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewfinder() {
    switch (_session.phase) {
      case CameraPhase.starting:
        return const StateScreen(spinner: true, message: 'Starting the camera…');
      case CameraPhase.denied:
        return StateScreen(
          icon: LucideIcons.cameraOff,
          message: 'Camera access is needed to scan a page.',
          detail: _session.deniedForGood
              ? "Ghostkey uses the camera to scan a page and extract its text into the current chapter. Allow the camera in your phone's settings, then try again — or choose a photo from your library."
              : 'Ghostkey uses the camera to scan a page and extract its text into the current chapter.',
          actionLabel: _session.deniedForGood ? 'Try again' : 'Grant access',
          onAction: _session.restart,
          secondaryActionLabel: 'Back',
          onSecondaryAction: widget.onClose,
        );
      case CameraPhase.failed:
        final error = _session.error;
        return StateScreen(
          icon: LucideIcons.cameraOff,
          message: 'The camera could not start.',
          detail: error is CameraException ? (error.description ?? error.code) : messageFor(error),
          actionLabel: 'Try again',
          onAction: _session.restart,
          secondaryActionLabel: 'Back',
          onSecondaryAction: widget.onClose,
        );
      case CameraPhase.ready:
        final controller = _session.controller!;
        final content = _session.previewSize ?? const Size(3, 4);
        final hint = _problem ??
            (_session.exposureLocked ? 'Exposure locked — tap to focus' : 'Hold steady — align the page in frame');
        return LayoutBuilder(
          builder: (context, constraints) {
            final box = constraints.biggest;
            return Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: content.width,
                    height: content.height,
                    child: CameraPreview(controller),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _busy ? null : (details) => _tap(box, details.localPosition),
                ),
                PageBrackets(hint: hint),
                if (_session.focusMark != null) FocusRing(at: _session.focusMark!),
                if (_fitting)
                  ColoredBox(
                    color: const Color(0x8A0A0914),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.flashOn, required this.onClose, required this.onFlash});
  final bool flashOn;
  final VoidCallback onClose;
  final VoidCallback onFlash;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 8),
          _BarButton(icon: LucideIcons.x, label: 'Close camera', color: Ds.soft, onPressed: onClose),
          Expanded(
            child: Text(
              'Scan a page',
              textAlign: TextAlign.center,
              style: DsStyle.ui(DsText.ui, color: Ds.hi, tracking: DsTracking.control),
            ),
          ),
          _BarButton(
            icon: flashOn ? LucideIcons.zap : LucideIcons.zapOff,
            label: 'Toggle flash',
            color: flashOn ? Ds.accent : Ds.mid,
            onPressed: onFlash,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.icon, required this.label, required this.color, required this.onPressed});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: label,
        builder: (context, pressed) => Opacity(
          opacity: pressed ? 0.6 : 1,
          child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 21, color: color)),
        ),
      );
}

class _SquareControl extends StatelessWidget {
  const _SquareControl({required this.icon, required this.label, required this.onPressed, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: label,
        builder: (context, pressed) => AnimatedContainer(
          duration: DsMotion.duration,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: pressed ? Ds.raise : Ds.surf,
            border: Border.all(color: active ? Ds.accentMix(55) : Ds.edge),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Opacity(
            opacity: onPressed == null ? 0.45 : 1,
            child: Icon(icon, size: 20, color: active ? Ds.accent : Ds.mid),
          ),
        ),
      );
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.enabled, required this.busy, required this.onPressed});
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        enabled: enabled,
        semanticLabel: 'Capture',
        builder: (context, pressed) => Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            width: 74,
            height: 74,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Ds.soft, width: 3),
            ),
            child: AnimatedContainer(
              duration: DsMotion.duration,
              width: pressed ? 52 : 58,
              height: pressed ? 52 : 58,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Ds.accent),
              child: busy
                  ? Padding(
                      padding: const EdgeInsets.all(18),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Ds.void_),
                    )
                  : null,
            ),
          ),
        ),
      );
}
