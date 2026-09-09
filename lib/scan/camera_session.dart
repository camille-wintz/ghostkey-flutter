import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// The camera behind the viewfinder: one controller, opened at the sensor's
// full resolution, with the controls the page scan cares about — flash,
// tap-to-focus (focus + metering point), an exposure lock, and the capture.
//
// Permission is the camera package's own flow: `initialize()` prompts on the
// first open and throws a `CameraAccess…` exception when refused, which is
// the `denied` phase here. There is no settings deep-link without another
// package, so a permanent refusal is worded, not fixed.
//
// The session follows the app's lifecycle: a backgrounded app releases the
// camera (Android reclaims it anyway), a resumed one reopens it — which is
// also how a grant made in the phone's settings comes back as `ready`.

enum CameraPhase { starting, ready, denied, failed }

class CameraSession extends ChangeNotifier with WidgetsBindingObserver {
  CameraController? _controller;
  CameraController? get controller => _controller;

  CameraPhase phase = CameraPhase.starting;

  /// With `denied`: the OS will not prompt again, so "try again" cannot help
  /// until the author grants it in settings.
  bool deniedForGood = false;

  /// With `failed`: what went wrong.
  Object? error;

  FlashMode flash = FlashMode.off;
  bool exposureLocked = false;
  bool capturing = false;

  /// The last tap-to-focus point in viewfinder coordinates, shown as a ring
  /// for a moment after the tap.
  Offset? focusMark;

  bool _disposed = false;
  bool _observing = false;
  Timer? _focusMarkTimer;

  /// The preview's size, oriented as the screen is held (the plugin reports
  /// it landscape on both platforms).
  Size? get previewSize {
    final size = _controller?.value.previewSize;
    if (size == null) return null;
    return Size(size.height, size.width);
  }

  Future<void> start() async {
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    await _open();
  }

  /// Re-run the open — the "try again" after a refusal or a failure.
  Future<void> restart() => _open();

  Future<void> _open() async {
    await _close();
    if (_disposed) return;
    phase = CameraPhase.starting;
    error = null;
    _notify();

    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('This phone has no camera.');
      final lens = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      // `max` is the sensor's highest still resolution; audio off so no
      // microphone permission rides along with the camera's.
      controller = CameraController(lens, ResolutionPreset.max, enableAudio: false);
      _controller = controller;
      await controller.initialize();
      if (_disposed) return;
      await _each([
        () => controller!.lockCaptureOrientation(DeviceOrientation.portraitUp),
        () => controller!.setFlashMode(flash),
        () => controller!.setFocusMode(FocusMode.auto),
        () => controller!.setExposureMode(exposureLocked ? ExposureMode.locked : ExposureMode.auto),
      ]);
      phase = CameraPhase.ready;
    } on CameraException catch (e) {
      if (e.code.startsWith('CameraAccess')) {
        phase = CameraPhase.denied;
        // 'CameraAccessDenied' is a refusal the OS may still ask about again;
        // the "WithoutPrompt" and "Restricted" codes will not.
        deniedForGood = e.code != 'CameraAccessDenied';
      } else {
        phase = CameraPhase.failed;
        error = e;
      }
    } catch (e) {
      phase = CameraPhase.failed;
      error = e;
    }
    if (phase != CameraPhase.ready) await _close();
    _notify();
  }

  Future<void> _close() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {
        // Already gone; nothing to release.
      }
    }
  }

  Future<void> toggleFlash() async {
    final controller = _controller;
    final next = flash == FlashMode.off ? FlashMode.always : FlashMode.off;
    if (controller == null || phase != CameraPhase.ready) {
      flash = next;
      _notify();
      return;
    }
    try {
      await controller.setFlashMode(next);
      flash = next;
    } on CameraException {
      // No flash on this lens; the toggle stays where it was.
    }
    _notify();
  }

  Future<void> toggleExposureLock() async {
    final controller = _controller;
    if (controller == null || phase != CameraPhase.ready) return;
    final next = !exposureLocked;
    try {
      await controller.setExposureMode(next ? ExposureMode.locked : ExposureMode.auto);
      exposureLocked = next;
    } on CameraException {
      // Not supported on this device; the control stays inert.
    }
    _notify();
  }

  /// Focus and meter on a point: `normalized` is the preview fraction the
  /// camera wants, `mark` the viewfinder point the ring is drawn at.
  Future<void> focusAt({required Offset normalized, required Offset mark}) async {
    final controller = _controller;
    if (controller == null || phase != CameraPhase.ready) return;
    focusMark = mark;
    _focusMarkTimer?.cancel();
    _focusMarkTimer = Timer(const Duration(milliseconds: 1100), () {
      focusMark = null;
      _notify();
    });
    _notify();
    await _each([
      () => controller.setFocusPoint(normalized),
      // A locked exposure is the author's choice; a tap must not quietly
      // re-meter it.
      if (!exposureLocked) () => controller.setExposurePoint(normalized),
    ]);
  }

  /// One full-resolution still, as the plugin's JPEG bytes. Null when the
  /// camera is not ready or a capture is already under way.
  Future<Uint8List?> capture() async {
    final controller = _controller;
    if (controller == null || phase != CameraPhase.ready || capturing) return null;
    capturing = true;
    _notify();
    try {
      final file = await controller.takePicture();
      return await file.readAsBytes();
    } finally {
      capturing = false;
      _notify();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (_controller != null) {
          phase = CameraPhase.starting;
          unawaited(_close());
          _notify();
        }
      case AppLifecycleState.resumed:
        unawaited(_open());
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Run each control call, swallowing what this device does not support —
  /// a missing focus point is not a reason to lose the preview.
  Future<void> _each(List<Future<void> Function()> calls) async {
    for (final call in calls) {
      try {
        await call();
      } on CameraException {
        continue;
      } on ArgumentError {
        continue;
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _focusMarkTimer?.cancel();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    unawaited(_close());
    super.dispose();
  }
}
