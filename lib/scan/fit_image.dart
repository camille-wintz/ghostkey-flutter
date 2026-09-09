import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

// Re-encode an image inside a pixel budget — the RN app's `lib/fitImage.ts`.
//
// Capture surfaces hand over whatever the camera shot: a phone photo is
// routinely 12 MP / 4-6 MB, which costs upload time, a multi-megabyte base64
// string in memory and (past the server's cap) a 413, for pixels the vision
// model downsamples anyway. This shrinks the raster on-device, before anything
// is encoded or sent. Re-encoding also normalises the format, so a library
// pick never reaches the server as something it does not speak.
//
// Knows nothing about who is asking or why: give it bytes and a budget, get
// back a JPEG.

/// An encoded raster image: `bytes` to render, `base64` to upload.
class EncodedImage {
  const EncodedImage({required this.bytes, required this.width, required this.height});
  final Uint8List bytes;
  final int width;
  final int height;

  String get mimeType => 'image/jpeg';
  String get base64 => base64Encode(bytes);
}

class FitOptions {
  const FitOptions({required this.maxEdge, this.maxPixels, this.quality = 0.8});

  /// Longest side, in pixels.
  final int maxEdge;

  /// Ceiling on total pixels (width × height). Defaults to `maxEdge` squared.
  final int? maxPixels;

  /// JPEG quality, 0..1.
  final double quality;
}

/// Scale factor (≤ 1) bringing `width × height` inside both budgets.
double fitScale(int width, int height, FitOptions options) {
  if (width <= 0 || height <= 0) return 1;
  final byEdge = options.maxEdge / math.max(width, height);
  final byArea = math.sqrt((options.maxPixels ?? options.maxEdge * options.maxEdge) / (width * height));
  return math.min(1, math.min(byEdge, byArea));
}

/// Decode `source`, bake its EXIF orientation in, scale it inside `options`
/// and encode it as JPEG. Runs off the UI isolate: decoding a 12 MP JPEG in
/// pure Dart is seconds of work.
Future<EncodedImage> fitImage(Uint8List source, FitOptions options) =>
    compute(_fit, (source, options), debugLabel: 'fitImage');

EncodedImage _fit((Uint8List, FitOptions) args) {
  final (source, options) = args;
  // A decoder given a format it half-recognises can throw rather than return
  // null; either way the author hears the same thing.
  img.Image? decoded;
  try {
    decoded = img.decodeImage(source);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) throw StateError('Could not read that image.');

  // A camera JPEG carries its rotation as EXIF, which the re-encode drops —
  // apply it to the pixels first or a portrait page arrives lying on its side.
  var image = img.bakeOrientation(decoded);

  final scale = fitScale(image.width, image.height, options);
  if (scale < 1) {
    // Only the width is set: the aspect ratio is kept. Area averaging rather
    // than bilinear — thin pen strokes survive a 3× downscale that way.
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }

  final quality = (options.quality * 100).round().clamp(1, 100);
  return EncodedImage(
    bytes: img.encodeJpg(image, quality: quality),
    width: image.width,
    height: image.height,
  );
}
