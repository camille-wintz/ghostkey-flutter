import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/scan/fit_image.dart';
import 'package:image/image.dart' as img;

void main() {
  const budget = FitOptions(maxEdge: 1568, maxPixels: 1150000, quality: 0.8);

  group('fitScale', () {
    test('leaves an image inside both budgets alone', () {
      expect(fitScale(800, 600, budget), 1);
    });

    test('never scales up', () {
      expect(fitScale(100, 100, const FitOptions(maxEdge: 1000)), 1);
    });

    test('is 1 for a degenerate size', () {
      expect(fitScale(0, 600, budget), 1);
      expect(fitScale(800, -1, budget), 1);
    });

    test('the pixel ceiling binds before the edge on a 4:3 photo', () {
      // 4000 × 3000 = 12 MP. By edge: 1568/4000 = 0.392 → 1568 × 1176 = 1.84 MP,
      // over the 1.15 MP ceiling. By area: √(1.15M / 12M) ≈ 0.3096.
      final scale = fitScale(4000, 3000, budget);
      expect(scale, closeTo(0.3096, 0.0005));
      expect((4000 * scale) * (3000 * scale), lessThanOrEqualTo(1150000 + 1));
    });

    test('the edge binds on a long strip', () {
      // 4000 × 200: 0.8 MP is under the ceiling, but the edge is not.
      expect(fitScale(4000, 200, budget), closeTo(1568 / 4000, 1e-9));
    });

    test('maxPixels defaults to maxEdge squared', () {
      const square = FitOptions(maxEdge: 100);
      expect(fitScale(200, 50, square), 0.5);
    });
  });

  group('fitImage', () {
    test('re-encodes as JPEG inside the budget, keeping the aspect ratio', () async {
      final source = img.Image(width: 400, height: 300);
      img.fill(source, color: img.ColorRgb8(200, 40, 40));
      final bytes = img.encodePng(source);

      final out = await fitImage(bytes, const FitOptions(maxEdge: 100, quality: 0.8));

      expect(out.width, 100);
      expect(out.height, 75);
      expect(out.mimeType, 'image/jpeg');
      expect(img.findDecoderForData(out.bytes), isA<img.JpegDecoder>());
      expect(out.base64, isNotEmpty);
    });

    test('bakes the EXIF orientation into the pixels', () async {
      // 200 wide × 100 tall, tagged "rotate 90° clockwise" (orientation 6):
      // the baked image is 100 × 200.
      final source = img.Image(width: 200, height: 100);
      source.exif.imageIfd.orientation = 6;
      final bytes = img.encodeJpg(source);

      final out = await fitImage(bytes, const FitOptions(maxEdge: 1000));

      expect(out.width, 100);
      expect(out.height, 200);
    });

    test('refuses bytes that are not an image', () async {
      await expectLater(
        fitImage(img.encodePng(img.Image(width: 1, height: 1)).sublist(0, 4), const FitOptions(maxEdge: 10)),
        throwsA(isA<StateError>()),
      );
    });
  });
}
