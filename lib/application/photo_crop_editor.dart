import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../src/rust/api.dart' as core;
import 'photo_crop_geometry.dart';

class PhotoCropEditor extends StatefulWidget {
  final Uint8List source;
  final PixelCrop? initial;
  const PhotoCropEditor({super.key, required this.source, this.initial});
  @override
  State<PhotoCropEditor> createState() => _PhotoCropEditorState();
}

class _PhotoCropEditorState extends State<PhotoCropEditor> {
  final fields = List.generate(4, (_) => TextEditingController());
  final handles = [FocusNode(), FocusNode()];
  final history = <PixelCrop>[];
  int imageWidth = 0, imageHeight = 0;
  PixelCrop? selection;
  core.StudioOutput? preview;
  String? error;
  String aspect = 'free';
  bool loading = true, previewReady = false;
  Offset? dragOrigin;
  PixelCrop? dragSelection;
  int selectedHandle = 0;
  static const ratios = <String, double?>{
    'free': null,
    'square': 1,
    'portrait': 3 / 4,
    'landscape': 4 / 3,
    'passport': 35 / 45,
  };
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    for (final handle in handles) {
      handle.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final dimensions = await core.photoSourceDimensions(data: widget.source);
      final image = await core.previewSourceImage(
        data: widget.source,
        maxPixels: 1200,
      );
      if (!mounted) return;
      imageWidth = dimensions[0];
      imageHeight = dimensions[1];
      final initial = widget.initial;
      final value = initial != null && initial.fits(imageWidth, imageHeight)
          ? initial
          : PixelCrop(0, 0, imageWidth, imageHeight);
      setState(() {
        preview = image;
        selection = value;
        loading = false;
      });
      syncFields();
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.toString();
        });
      }
    }
  }

  void syncFields() {
    final crop = selection!;
    final values = [crop.x, crop.y, crop.width, crop.height];
    for (var i = 0; i < 4; i++) {
      fields[i].text = '${values[i]}';
    }
  }

  void remember() {
    history.add(selection!);
    if (history.length > 50) history.removeAt(0);
  }

  void update(PixelCrop value, {bool record = true}) {
    if (record) remember();
    setState(() {
      selection = value;
      error = null;
    });
    syncFields();
  }

  PixelCrop? readFields() {
    final values = fields.map((f) => int.tryParse(f.text)).toList();
    if (values.any((v) => v == null)) {
      setState(() => error = 'Enter whole-pixel coordinates.');
      return null;
    }
    final value = PixelCrop(values[0]!, values[1]!, values[2]!, values[3]!);
    if (!value.fits(imageWidth, imageHeight)) {
      setState(
        () => error =
            'Crop must fit inside $imageWidth × $imageHeight pixels and be at least 1 × 1.',
      );
      return null;
    }
    if (!value.matchesAspect(ratios[aspect])) {
      setState(
        () => error =
            'Dimensions must match the selected aspect ratio within one pixel.',
      );
      return null;
    }
    return value;
  }

  KeyEventResult nudge(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (![
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
    ].contains(key)) {
      return KeyEventResult.ignored;
    }
    final amount = HardwareKeyboard.instance.isShiftPressed ? 10 : 1;
    final dx = key == LogicalKeyboardKey.arrowLeft
        ? -amount
        : key == LogicalKeyboardKey.arrowRight
        ? amount
        : 0;
    final dy = key == LogicalKeyboardKey.arrowUp
        ? -amount
        : key == LogicalKeyboardKey.arrowDown
        ? amount
        : 0;
    final crop = selection!;
    final px = index == 0 ? crop.x : crop.x + crop.width;
    final py = index == 0 ? crop.y : crop.y + crop.height;
    update(
      crop.moveCorner(
        index == 0,
        px + dx,
        py + dy,
        imageWidth,
        imageHeight,
        ratios[aspect],
      ),
    );
    return KeyEventResult.handled;
  }

  void beginDrag(DragStartDetails details, [int? index]) {
    remember();
    dragOrigin = details.globalPosition;
    dragSelection = selection;
    if (index != null) handles[index].requestFocus();
  }

  void dragCorner(
    int index,
    DragUpdateDetails details,
    double width,
    double height,
  ) {
    final crop = dragSelection ?? selection!;
    final delta =
        details.globalPosition - (dragOrigin ?? details.globalPosition);
    final px = index == 0 ? crop.x : crop.x + crop.width;
    final py = index == 0 ? crop.y : crop.y + crop.height;
    update(
      crop.moveCorner(
        index == 0,
        px + (delta.dx / width * imageWidth).round(),
        py + (delta.dy / height * imageHeight).round(),
        imageWidth,
        imageHeight,
        ratios[aspect],
      ),
      record: false,
    );
  }

  void dragRectangle(DragUpdateDetails details, Size size) {
    final delta =
        details.globalPosition - (dragOrigin ?? details.globalPosition);
    update(
      (dragSelection ?? selection!).translate(
        (delta.dx / size.width * imageWidth).round(),
        (delta.dy / size.height * imageHeight).round(),
        imageWidth,
        imageHeight,
      ),
      record: false,
    );
  }

  Widget handle(
    int index,
    double x,
    double y,
    double width,
    double height,
  ) => Positioned(
    left: x - 24,
    top: y - 24,
    width: 48,
    height: 48,
    child: Focus(
      focusNode: handles[index],
      onKeyEvent: (_, event) => nudge(index, event),
      onFocusChange: (focused) {
        if (focused) setState(() => selectedHandle = index);
      },
      child: Semantics(
        button: true,
        label: index == 0 ? 'Top left crop handle' : 'Bottom right crop handle',
        hint: 'Drag, or focus and use arrow keys. Shift changes ten pixels.',
        child: GestureDetector(
          key: ValueKey('photo-crop-handle-$index'),
          dragStartBehavior: DragStartBehavior.down,
          behavior: HitTestBehavior.opaque,
          onTap: () => handles[index].requestFocus(),
          onHorizontalDragStart: (details) => beginDrag(details, index),
          onVerticalDragStart: (details) => beginDrag(details, index),
          onHorizontalDragUpdate: (details) =>
              dragCorner(index, details, width, height),
          onVerticalDragUpdate: (details) =>
              dragCorner(index, details, width, height),
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selectedHandle == index
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white,
                border: Border.all(color: Colors.black, width: 2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.drag_handle,
                size: 18,
                color: selectedHandle == index
                    ? Theme.of(context).colorScheme.onPrimary
                    : Colors.black,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget sourceImage() => Image.memory(
    preview!.bytes,
    fit: BoxFit.fill,
    gaplessPlayback: true,
    frameBuilder: (context, child, frame, synchronous) {
      if ((frame != null || synchronous) && !previewReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => previewReady = true);
        });
      }
      return child;
    },
    errorBuilder: (context, _, _) => const Text(
      'Preview could not be decoded. Cancel and choose another image.',
    ),
    semanticLabel: 'Orientation-corrected source with crop selection',
  );

  Widget imageView() => LayoutBuilder(
    builder: (context, constraints) {
      const margin = 24.0;
      final width = math.max(
        1.0,
        math.min(800.0, constraints.maxWidth - margin * 2),
      );
      final height = math.min(420.0, MediaQuery.sizeOf(context).height * .42);
      final size = applyBoxFit(
        BoxFit.contain,
        Size(imageWidth.toDouble(), imageHeight.toDouble()),
        Size(width, height),
      ).destination;
      final crop = selection!;
      final rect = Rect.fromLTWH(
        margin + crop.x / imageWidth * size.width,
        margin + crop.y / imageHeight * size.height,
        crop.width / imageWidth * size.width,
        crop.height / imageHeight * size.height,
      );
      return Center(
        child: SizedBox(
          width: size.width + margin * 2,
          height: size.height + margin * 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: margin,
                top: margin,
                width: size.width,
                height: size.height,
                child: sourceImage(),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _CropPainter(rect)),
                ),
              ),
              Positioned(
                left: rect.left,
                top: rect.top,
                width: rect.width,
                height: rect.height,
                child: GestureDetector(
                  dragStartBehavior: DragStartBehavior.down,
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (details) => beginDrag(details),
                  onVerticalDragStart: (details) => beginDrag(details),
                  onHorizontalDragUpdate: (details) =>
                      dragRectangle(details, size),
                  onVerticalDragUpdate: (details) =>
                      dragRectangle(details, size),
                ),
              ),
              handle(0, rect.left, rect.top, size.width, size.height),
              handle(1, rect.right, rect.bottom, size.width, size.height),
            ],
          ),
        ),
      );
    },
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Crop photo')),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: selection == null || !previewReady
              ? null
              : () {
                  final value = readFields();
                  if (value != null) Navigator.pop(context, value);
                },
          child: const Text('Use crop'),
        ),
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Drag the two corners or move the selection. Crop uses orientation-corrected original pixels, before resizing. Your original stays unchanged.',
                ),
                if (loading) const LinearProgressIndicator(),
                if (preview != null && selection != null) ...[
                  Text('Original: $imageWidth × $imageHeight pixels'),
                  imageView(),
                  DropdownButtonFormField<String>(
                    key: ValueKey(aspect),
                    initialValue: aspect,
                    isExpanded: true,
                    itemHeight: null,
                    decoration: const InputDecoration(
                      labelText: 'Aspect ratio',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'free', child: Text('Free')),
                      DropdownMenuItem(value: 'square', child: Text('1:1')),
                      DropdownMenuItem(value: 'portrait', child: Text('3:4')),
                      DropdownMenuItem(value: 'landscape', child: Text('4:3')),
                      DropdownMenuItem(value: 'passport', child: Text('35:45')),
                    ],
                    onChanged: (value) {
                      aspect = value!;
                      update(
                        aspect == 'free'
                            ? selection!
                            : PixelCrop.largest(
                                imageWidth,
                                imageHeight,
                                ratios[aspect],
                              ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Selected: ${selection!.width} × ${selection!.height} pixels',
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: history.isEmpty
                            ? null
                            : () {
                                final prior = history.removeLast();
                                aspect = 'free';
                                update(prior, record: false);
                              },
                        child: const Text('Undo'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          aspect = 'free';
                          update(PixelCrop(0, 0, imageWidth, imageHeight));
                        },
                        child: const Text('Full image'),
                      ),
                    ],
                  ),
                  const Text(
                    'Exact pixels. Arrow keys move the focused corner by one pixel; Shift moves ten.',
                  ),
                  for (var i = 0; i < 4; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: TextField(
                        controller: fields[i],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: [
                            'Left edge (pixels)',
                            'Top edge (pixels)',
                            'Crop width (pixels)',
                            'Crop height (pixels)',
                          ][i],
                        ),
                        onSubmitted: (_) {
                          final value = readFields();
                          if (value != null) update(value);
                        },
                      ),
                    ),
                  OutlinedButton(
                    onPressed: () {
                      final value = readFields();
                      if (value != null) update(value);
                    },
                    child: const Text('Update crop'),
                  ),
                ],
                if (error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CropPainter extends CustomPainter {
  final Rect rect;
  _CropPainter(this.rect);
  @override
  void paint(Canvas canvas, Size size) {
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(24, 24, size.width - 48, size.height - 48))
      ..addRect(rect);
    canvas.drawPath(mask, Paint()..color = Colors.black.withValues(alpha: .55));
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _CropPainter old) => old.rect != rect;
}
