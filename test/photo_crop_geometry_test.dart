import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_studio_toolkit/application/photo_crop_geometry.dart';

void main() {
  test(
    'full source, aspect locks and translations preserve valid integer bounds',
    () {
      for (final size in [(4000, 3000), (3, 1), (1, 3), (1, 1), (300, 100)]) {
        for (final ratio in <double?>[null, 1, 3 / 4, 4 / 3, 35 / 45]) {
          final crop = PixelCrop.largest(size.$1, size.$2, ratio);
          expect(crop.fits(size.$1, size.$2), isTrue);
          expect(crop.matchesAspect(ratio), isTrue);
          final moved = crop.translate(-10000, 10000, size.$1, size.$2);
          expect(moved.fits(size.$1, size.$2), isTrue);
          expect(moved.width, crop.width);
          expect(moved.height, crop.height);
        }
      }
    },
  );
  test(
    'corner drags remain bounded and preserve the opposite corner and aspect',
    () {
      final random = Random(42);
      for (final ratio in <double?>[null, 1, 3 / 4, 4 / 3, 35 / 45]) {
        for (var i = 0; i < 400; i++) {
          const start = PixelCrop(100, 100, 300, 200);
          final topLeft = i.isEven;
          final crop = start.moveCorner(
            topLeft,
            random.nextInt(1400) - 300,
            random.nextInt(1000) - 200,
            800,
            600,
            ratio,
          );
          expect(crop.fits(800, 600), isTrue);
          expect(crop.matchesAspect(ratio), isTrue);
          if (topLeft) {
            expect(crop.x + crop.width, start.x + start.width);
            expect(crop.y + crop.height, start.y + start.height);
          } else {
            expect(crop.x, start.x);
            expect(crop.y, start.y);
          }
        }
      }
      const square = PixelCrop(10, 20, 100, 100);
      final unchanged = square.moveCorner(false, 110, 120, 1000, 1000, 1);
      expect(
        [unchanged.x, unchanged.y, unchanged.width, unchanged.height],
        [10, 20, 100, 100],
      );
    },
  );
}
