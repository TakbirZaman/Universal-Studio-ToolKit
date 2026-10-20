import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:universal_studio_toolkit/src/rust/frb_generated.dart';
import 'package:universal_studio_toolkit/src/rust/api.dart' as core;
import 'package:universal_studio_toolkit/src/rust/scanner.dart';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_studio_toolkit/application/scan_corners.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'manual straightening produces actual horizontal lines through Rust',
    () async {
      await RustLib.init(
        externalLibrary: ExternalLibrary.open(
          Platform.environment['UST_CORE_LIBRARY'] ??
              '${Directory.current.path}/rust/target/debug/libstudio_core.so',
        ),
      );
      const width = 301, height = 401;
      for (final angle in [-7.0, 7.0]) {
        final pixels = Uint8List(width * height * 4);
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final distance =
                y -
                height / 2 -
                math.tan(angle * math.pi / 180) * (x - width / 2);
            final dark = distance % 32 < 6;
            final index = (y * width + x) * 4;
            pixels[index] = pixels[index + 1] = pixels[index + 2] = dark
                ? 0
                : 255;
            pixels[index + 3] = 255;
          }
        }
        final decoded = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          pixels,
          width,
          height,
          ui.PixelFormat.rgba8888,
          decoded.complete,
        );
        final sourceImage = await decoded.future;
        final source = (await sourceImage.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        sourceImage.dispose();
        final unchanged = Uint8List.fromList(source);
        final result = await core.previewScanPage(
          data: source,
          options: ScanOptions(
            mode: ScanMode.original,
            rotateQuarters: 0,
            brightness: 0,
            contrast: 0,
            threshold: 128,
            corners: straightenOutline(fullPageCorners(), angle, width, height),
          ),
          maxPixels: 1600,
        );
        final codec = await ui.instantiateImageCodec(result.bytes);
        final image = (await codec.getNextFrame()).image;
        final output = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        // Text-line positions at widely separated columns should agree within one
        // pixel after deskew. Compare thresholded runs, excluding boundary rows.
        List<int> starts(int x) => [
          for (var y = 10; y < image.height - 10; y++)
            if (output[(y * image.width + x) * 4] < 128 &&
                output[((y - 1) * image.width + x) * 4] >= 128)
              y,
        ];
        final left = starts(image.width ~/ 5),
            right = starts(image.width * 4 ~/ 5);
        expect(left.length, greaterThan(5));
        expect(right.length, left.length);
        for (var i = 0; i < left.length; i++) {
          expect((left[i] - right[i]).abs(), lessThanOrEqualTo(1));
        }
        expect(source, unchanged);
        image.dispose();
        codec.dispose();
      }
    },
    skip: Platform.environment['UST_VISION_LIBRARY'] == null,
  );

  test(
    'straightening respects pixel aspect, angle and inscribed boundaries',
    () {
      final base = fullPageCorners();
      expect(straightenOutline(base, 0, 301, 801), same(base));
      for (final size in [(301, 801), (801, 301), (301, 301)]) {
        for (final angle in [-10.0, -5.0, 5.0, 10.0]) {
          final result = straightenOutline(base, angle, size.$1, size.$2);
          expect(cornerError(result), isNull);
          final points = cornerPoints(result);
          expect(
            points.every((p) => p.x >= 0 && p.x <= 1 && p.y >= 0 && p.y <= 1),
            isTrue,
          );
          final dx = (result.topRight.x - result.topLeft.x) * (size.$1 - 1);
          final dy = (result.topRight.y - result.topLeft.y) * (size.$2 - 1);
          expect(math.atan2(dy, dx) * 180 / math.pi, closeTo(angle, 1e-9));
          // Uniform shrink preserves the original physical aspect ratio.
          final sideX =
              (result.bottomLeft.x - result.topLeft.x) * (size.$1 - 1);
          final sideY =
              (result.bottomLeft.y - result.topLeft.y) * (size.$2 - 1);
          expect(
            math.sqrt(dx * dx + dy * dy) /
                math.sqrt(sideX * sideX + sideY * sideY),
            closeTo((size.$1 - 1) / (size.$2 - 1), 1e-9),
          );
        }
      }
      for (final angle in [double.nan, double.infinity, -10.1, 10.1]) {
        expect(
          () => straightenOutline(base, angle, 301, 801),
          throwsFormatException,
        );
      }
      expect(() => straightenOutline(base, 2, 1, 801), throwsFormatException);
    },
  );
}
