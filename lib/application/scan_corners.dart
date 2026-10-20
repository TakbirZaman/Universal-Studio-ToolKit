import 'dart:math' as math;

import '../src/rust/vision.dart';

List<PagePoint> cornerPoints(PageCorners c) => [
  c.topLeft,
  c.topRight,
  c.bottomRight,
  c.bottomLeft,
];
PageCorners cornersFromPoints(List<PagePoint> p) => PageCorners(
  topLeft: p[0],
  topRight: p[1],
  bottomRight: p[2],
  bottomLeft: p[3],
);
PageCorners fullPageCorners() => const PageCorners(
  topLeft: PagePoint(x: 0, y: 0),
  topRight: PagePoint(x: 1, y: 0),
  bottomRight: PagePoint(x: 1, y: 1),
  bottomLeft: PagePoint(x: 0, y: 1),
);

/// Inline feedback only. Rust independently validates before native processing.
String? cornerError(PageCorners c) {
  final p = cornerPoints(c);
  var area = 0.0;
  for (var i = 0; i < 4; i++) {
    final a = p[i], b = p[(i + 1) % 4], next = p[(i + 2) % 4];
    if (!a.x.isFinite ||
        !a.y.isFinite ||
        a.x < 0 ||
        a.y < 0 ||
        a.x > 1 ||
        a.y > 1 ||
        (b.x - a.x) * (next.y - b.y) - (b.y - a.y) * (next.x - b.x) <=
            0.000001) {
      return 'Keep all four corners inside the image, clockwise around the page, without crossing.';
    }
    area += a.x * b.y - b.x * a.y;
  }
  return area < 0.02
      ? 'Choose a page covering at least 1% of the image.'
      : null;
}

List<double>? encodeCorners(PageCorners? c) =>
    c == null ? null : cornerPoints(c).expand((p) => [p.x, p.y]).toList();
PageCorners? decodeCorners(Object? value) {
  if (value == null) return null;
  if (value is! List || value.length != 8 || value.any((n) => n is! num)) {
    throw const FormatException('Invalid page corners.');
  }
  final p = [
    for (var i = 0; i < 8; i += 2)
      PagePoint(
        x: (value[i] as num).toDouble(),
        y: (value[i + 1] as num).toDouble(),
      ),
  ];
  final c = cornersFromPoints(p);
  if (cornerError(c) != null) {
    throw const FormatException('Invalid page corners.');
  }
  return c;
}

/// Rotate the selected source outline in physical pixel coordinates. The native
/// perspective operation then maps this tilted outline to a straight rectangle.
/// Shrink uniformly about its centre when needed; never clip individual points.
PageCorners straightenOutline(
  PageCorners base,
  double degrees,
  int width,
  int height,
) {
  if (!degrees.isFinite ||
      degrees.abs() > 10 ||
      width < 2 ||
      height < 2 ||
      cornerError(base) != null) {
    throw const FormatException(
      'Use a valid outline and an angle from -10 to 10 degrees.',
    );
  }
  if (degrees == 0) return base;
  final points = cornerPoints(base);
  final w = (width - 1).toDouble(), h = (height - 1).toDouble();
  final cx = points.fold(0.0, (sum, p) => sum + p.x * w) / 4;
  final cy = points.fold(0.0, (sum, p) => sum + p.y * h) / 4;
  final angle = degrees * math.pi / 180;
  final cosine = math.cos(angle), sine = math.sin(angle);
  final rotated = points.map((p) {
    final dx = p.x * w - cx, dy = p.y * h - cy;
    return (x: dx * cosine - dy * sine, y: dx * sine + dy * cosine);
  }).toList();
  var scale = 1.0;
  for (final p in rotated) {
    if (p.x < 0) scale = math.min(scale, cx / -p.x);
    if (p.x > 0) scale = math.min(scale, (w - cx) / p.x);
    if (p.y < 0) scale = math.min(scale, cy / -p.y);
    if (p.y > 0) scale = math.min(scale, (h - cy) / p.y);
  }
  final result = cornersFromPoints(
    rotated
        .map(
          (p) => PagePoint(
            x: ((cx + p.x * scale) / w).clamp(0, 1).toDouble(),
            y: ((cy + p.y * scale) / h).clamp(0, 1).toDouble(),
          ),
        )
        .toList(),
  );
  if (cornerError(result) != null) {
    throw const FormatException(
      'This outline becomes too small. Use a larger page selection.',
    );
  }
  return result;
}
