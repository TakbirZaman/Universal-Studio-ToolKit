import 'dart:math' as math;

class PixelCrop {
  final int x, y, width, height;
  const PixelCrop(this.x, this.y, this.width, this.height);
  bool fits(int imageWidth, int imageHeight) =>
      x >= 0 &&
      y >= 0 &&
      width >= 1 &&
      height >= 1 &&
      x + width <= imageWidth &&
      y + height <= imageHeight;
  bool matchesAspect(double? ratio) =>
      ratio == null || (width - height * ratio).abs() <= 1.01;
  PixelCrop translate(int dx, int dy, int imageWidth, int imageHeight) =>
      PixelCrop(
        (x + dx).clamp(0, imageWidth - width),
        (y + dy).clamp(0, imageHeight - height),
        width,
        height,
      );
  PixelCrop moveCorner(
    bool topLeft,
    int px,
    int py,
    int imageWidth,
    int imageHeight,
    double? ratio,
  ) {
    final anchorX = topLeft ? x + width : x;
    final anchorY = topLeft ? y + height : y;
    final maxW = topLeft ? anchorX : imageWidth - anchorX;
    final maxH = topLeft ? anchorY : imageHeight - anchorY;
    var w = (topLeft ? anchorX - px : px - anchorX).clamp(1, maxW);
    var h = (topLeft ? anchorY - py : py - anchorY).clamp(1, maxH);
    if (ratio != null) {
      // Project onto the aspect ray and keep the opposite corner fixed.
      final projected = ((w * ratio + h) / (1 + ratio * ratio) * ratio).round();
      w = projected.clamp(1, maxW);
      h = (w / ratio).round().clamp(1, maxH);
      w = (h * ratio).round().clamp(1, maxW);
      h = (w / ratio).round().clamp(1, maxH);
    }
    return PixelCrop(
      topLeft ? anchorX - w : anchorX,
      topLeft ? anchorY - h : anchorY,
      w,
      h,
    );
  }

  static PixelCrop largest(int imageWidth, int imageHeight, double? ratio) {
    if (ratio == null) return PixelCrop(0, 0, imageWidth, imageHeight);
    var width = math
        .min(imageWidth, (imageHeight * ratio).floor())
        .clamp(1, imageWidth);
    var height = (width / ratio).round().clamp(1, imageHeight);
    width = (height * ratio).round().clamp(1, imageWidth);
    height = (width / ratio).round().clamp(1, imageHeight);
    return PixelCrop(
      (imageWidth - width) ~/ 2,
      (imageHeight - height) ~/ 2,
      width,
      height,
    );
  }
}
