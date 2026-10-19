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
