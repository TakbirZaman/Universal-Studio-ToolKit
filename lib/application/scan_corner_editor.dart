import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../src/rust/api.dart' as core;
import '../src/rust/vision.dart';
import 'scan_corners.dart';

class CornerEditResult {
  final PageCorners? corners;
  const CornerEditResult(this.corners);
}

class ScanCornerEditor extends StatefulWidget {
  final Uint8List source;
  final PageCorners? initial;
  const ScanCornerEditor({super.key, required this.source, this.initial});
  @override
  State<ScanCornerEditor> createState() => _ScanCornerEditorState();
}

class _ScanCornerEditorState extends State<ScanCornerEditor> {
  late PageCorners corners;
  final history = <PageCorners>[];
  final cornerFocus = List.generate(4, (_) => FocusNode());
  core.StudioOutput? image;
  String? error, message;
  int selected = 0;
  bool working = true, previewReady = false;
  static const labels = [
    'Top left',
    'Top right',
    'Bottom right',
    'Bottom left',
  ];
  @override
  void initState() {
    super.initState();
    corners = widget.initial ?? fullPageCorners();
    load();
  }

  @override
  void dispose() {
    for (final node in cornerFocus) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final result = await core.previewSourceImage(
        data: widget.source,
        maxPixels: 1000,
      );
      if (mounted) setState(() => image = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not preview this image. Your page is unchanged.',
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  void remember() {
    history.add(corners);
    if (history.length > 50) history.removeAt(0);
  }

  void move(int i, double x, double y, {bool record = true}) {
    if (record) remember();
    final p = cornerPoints(corners);
    p[i] = PagePoint(x: x.clamp(0, 1).toDouble(), y: y.clamp(0, 1).toDouble());
    setState(() {
      corners = cornersFromPoints(p);
      selected = i;
      message = null;
    });
  }

  Future<void> suggest() async {
    setState(() {
      working = true;
      message = null;
    });
    try {
      final proposed = await core.suggestScanEdges(data: widget.source);
      if (mounted) {
        setState(() {
          if (proposed == null) {
            message =
                'No clear page boundary found. Set the four corners manually.';
          } else {
            remember();
            corners = proposed;
            message =
                'Suggested corners only. Check every edge before applying.';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'Could not suggest edges. Set the corners manually.',
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = working || !previewReady;
    final invalid = cornerError(corners),
        p = cornerPoints(corners),
        theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Set page corners')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: blocked || image == null || invalid != null
              ? null
              : () => Navigator.pop(context, CornerEditResult(corners)),
          icon: const Icon(Icons.check),
          label: const Text('Apply corners and preview'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Move the four numbered corners to the edges of your page. Rotation and appearance are applied afterward. Your original stays unchanged.',
                ),
                if (working)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Preparing page corners',
                  ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                if (image != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: LayoutBuilder(
                      builder: (context, bounds) {
                        final w = bounds.maxWidth - 48,
                            h = w * image!.height! / image!.width!;
                        return SizedBox(
                          width: w + 48,
                          height: h + 48,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: 24,
                                top: 24,
                                width: w,
                                height: h,
                                child: Image.memory(
                                  image!.bytes,
                                  fit: BoxFit.fill,
                                  semanticLabel:
                                      'Original page for corner placement',
                                  frameBuilder:
                                      (context, child, frame, synchronous) {
                                        if (frame == null && !synchronous) {
                                          return const Center(
                                            child: CircularProgressIndicator(
                                              semanticsLabel:
                                                  'Loading page image',
                                            ),
                                          );
                                        }
                                        if (!previewReady) {
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                if (mounted && !previewReady) {
                                                  setState(
                                                    () => previewReady = true,
                                                  );
                                                }
                                              });
                                        }
                                        return KeyedSubtree(
                                          key: const ValueKey(
                                            'corner-image-ready',
                                          ),
                                          child: child,
                                        );
                                      },
                                  errorBuilder: (context, error, stack) =>
                                      const Center(
                                        child: Text(
                                          'Could not display this page. Cancel and try a smaller image.',
                                        ),
                                      ),
                                ),
                              ),
                              Positioned(
                                left: 24,
                                top: 24,
                                width: w,
                                height: h,
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _CornerPainter(p),
                                  ),
                                ),
                              ),
                              for (var i = 0; i < 4; i++)
                                Positioned(
                                  left: p[i].x * w,
                                  top: p[i].y * h,
                                  width: 48,
                                  height: 48,
                                  child: Focus(
                                    skipTraversal: true,
                                    onKeyEvent: (node, event) {
                                      if (blocked ||
                                          event is! KeyDownEvent &&
                                              event is! KeyRepeatEvent) {
                                        return KeyEventResult.ignored;
                                      }
                                      final step =
                                          HardwareKeyboard
                                              .instance
                                              .isShiftPressed
                                          ? 0.01
                                          : 0.001;
                                      final key = event.logicalKey;
                                      if (![
                                        LogicalKeyboardKey.arrowLeft,
                                        LogicalKeyboardKey.arrowRight,
                                        LogicalKeyboardKey.arrowUp,
                                        LogicalKeyboardKey.arrowDown,
                                      ].contains(key)) {
                                        return KeyEventResult.ignored;
                                      }
                                      move(
                                        i,
                                        p[i].x +
                                            (key ==
                                                    LogicalKeyboardKey
                                                        .arrowRight
                                                ? step
                                                : key ==
                                                      LogicalKeyboardKey
                                                          .arrowLeft
                                                ? -step
                                                : 0),
                                        p[i].y +
                                            (key == LogicalKeyboardKey.arrowDown
                                                ? step
                                                : key ==
                                                      LogicalKeyboardKey.arrowUp
                                                ? -step
                                                : 0),
                                      );
                                      return KeyEventResult.handled;
                                    },
                                    child: GestureDetector(
                                      onPanStart: blocked
                                          ? null
                                          : (_) {
                                              remember();
                                              setState(() => selected = i);
                                            },
                                      onPanUpdate: blocked
                                          ? null
                                          : (d) => move(
                                              i,
                                              cornerPoints(corners)[i].x +
                                                  d.delta.dx / w,
                                              cornerPoints(corners)[i].y +
                                                  d.delta.dy / h,
                                              record: false,
                                            ),
                                      child: IconButton.filled(
                                        focusNode: cornerFocus[i],
                                        tooltip:
                                            '${labels[i]} corner. Drag or use arrow keys; Shift for larger steps.',
                                        onPressed: blocked
                                            ? null
                                            : () {
                                                cornerFocus[i].requestFocus();
                                                setState(() => selected = i);
                                              },
                                        style: IconButton.styleFrom(
                                          backgroundColor: selected == i
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.surface,
                                          foregroundColor: selected == i
                                              ? theme.colorScheme.onPrimary
                                              : theme.colorScheme.onSurface,
                                          side: BorderSide(
                                            color: theme.colorScheme.onSurface,
                                            width: 2,
                                          ),
                                        ),
                                        icon: Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: selected == i
                                                ? theme.colorScheme.onPrimary
                                                : theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: blocked || image == null ? null : suggest,
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Suggest edges'),
                    ),
                    OutlinedButton.icon(
                      onPressed: blocked || history.isEmpty
                          ? null
                          : () =>
                                setState(() => corners = history.removeLast()),
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo'),
                    ),
                    TextButton(
                      onPressed: blocked
                          ? null
                          : () {
                              remember();
                              setState(() => corners = fullPageCorners());
                            },
                      child: const Text('Use full image'),
                    ),
                  ],
                ),
                if (message != null)
                  Semantics(liveRegion: true, child: Text(message!)),
                if (image != null)
                  ExpansionTile(
                    title: const Text('Precise corner adjustment'),
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: selected,
                        key: ValueKey(selected),
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Corner'),
                        items: [
                          for (var i = 0; i < 4; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text('${i + 1}. ${labels[i]}'),
                            ),
                        ],
                        onChanged: blocked
                            ? null
                            : (value) => setState(() => selected = value!),
                      ),
                      Text(
                        'Horizontal: ${(p[selected].x * 100).toStringAsFixed(1)}%',
                      ),
                      Slider(
                        value: p[selected].x,
                        divisions: 1000,
                        semanticFormatterCallback: (v) =>
                            '${labels[selected]} horizontal ${(v * 100).toStringAsFixed(1)} percent',
                        onChangeStart: blocked ? null : (_) => remember(),
                        onChanged: blocked
                            ? null
                            : (v) => move(
                                selected,
                                v,
                                p[selected].y,
                                record: false,
                              ),
                      ),
                      Text(
                        'Vertical: ${(p[selected].y * 100).toStringAsFixed(1)}%',
                      ),
                      Slider(
                        value: p[selected].y,
                        divisions: 1000,
                        semanticFormatterCallback: (v) =>
                            '${labels[selected]} vertical ${(v * 100).toStringAsFixed(1)} percent',
                        onChangeStart: blocked ? null : (_) => remember(),
                        onChanged: blocked
                            ? null
                            : (v) => move(
                                selected,
                                p[selected].x,
                                v,
                                record: false,
                              ),
                      ),
                    ],
                  ),
                if (invalid != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      invalid,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: blocked
                      ? null
                      : () => Navigator.pop(
                          context,
                          const CornerEditResult(null),
                        ),
                  child: const Text('Remove corner correction'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final List<PagePoint> points;
  _CornerPainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(points[0].x * size.width, points[0].y * size.height);
    for (final p in points.skip(1)) {
      path.lineTo(p.x * size.width, p.y * size.height);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.black,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.points != points;
}
