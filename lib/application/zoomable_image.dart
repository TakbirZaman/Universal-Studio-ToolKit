import 'package:flutter/material.dart';

/// Receives canonical preview pixels, never unvalidated source bytes.
class ZoomableImage extends StatefulWidget {
  final Widget child;
  final double height;
  final Object imageIdentity;
  const ZoomableImage({
    super.key,
    required this.child,
    required this.imageIdentity,
    this.height = 360,
  });

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage> {
  final controller = TransformationController();
  double scale = 1;

  @override
  void didUpdateWidget(covariant ZoomableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.imageIdentity, widget.imageIdentity)) reset();
  }

  void reset() {
    controller.value = Matrix4.identity();
    scale = 1;
  }

  void zoom(double factor, Size viewport) {
    final next = (scale * factor).clamp(1.0, 8.0);
    if (next == 1) {
      setState(reset);
      return;
    }
    final ratio = next / scale;
    final old = controller.value;
    final x = viewport.width / 2;
    final y = viewport.height / 2;
    final transform = Matrix4.identity()
      ..setEntry(0, 0, next)
      ..setEntry(1, 1, next)
      ..setEntry(0, 3, x - (x - old.entry(0, 3)) * ratio)
      ..setEntry(1, 3, y - (y - old.entry(1, 3)) * ratio);
    setState(() {
      controller.value = transform;
      scale = next;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final viewport = Size(constraints.maxWidth, widget.height);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: widget.height,
            width: double.infinity,
            child: InteractiveViewer(
              transformationController: controller,
              minScale: 1,
              maxScale: 8,
              panEnabled: scale > 1,
              onInteractionUpdate: (_) =>
                  setState(() => scale = controller.value.getMaxScaleOnAxis()),
              child: SizedBox.expand(child: widget.child),
            ),
          ),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Zoom out',
                onPressed: scale > 1 ? () => zoom(0.5, viewport) : null,
                icon: const Icon(Icons.zoom_out),
              ),
              Semantics(
                liveRegion: true,
                child: Text('Preview zoom: ${scale.toStringAsFixed(1)}×'),
              ),
              IconButton(
                tooltip: 'Zoom in',
                onPressed: scale < 8 ? () => zoom(2, viewport) : null,
                icon: const Icon(Icons.zoom_in),
              ),
              TextButton(
                onPressed: scale > 1 ? () => setState(reset) : null,
                child: const Text('Reset zoom'),
              ),
            ],
          ),
          const Text('Pinch to zoom. Drag to pan when enlarged.'),
        ],
      );
    },
  );
}
