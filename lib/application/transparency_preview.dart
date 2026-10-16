import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Preview backgrounds never modify encoded output pixels.
class TransparencyPreview extends StatefulWidget {
  final Uint8List bytes;
  const TransparencyPreview({super.key, required this.bytes});
  @override
  State<TransparencyPreview> createState() => _TransparencyPreviewState();
}
class _TransparencyPreviewState extends State<TransparencyPreview> {
  String background = 'checkerboard';
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        initialValue: background,
        decoration: const InputDecoration(labelText: 'Preview background'),
        items: const [
          DropdownMenuItem(value: 'checkerboard', child: Text('Checkerboard')),
          DropdownMenuItem(value: 'light', child: Text('Light')),
          DropdownMenuItem(value: 'dark', child: Text('Dark')),
        ],
        onChanged: (value) => setState(() => background = value!),
      ),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: _Background(background),
          child: SizedBox(height: 360, width: double.infinity,
            child: Image.memory(widget.bytes, fit: BoxFit.contain,
              semanticLabel: 'Prepared image with transparency',
              errorBuilder: (_, _, _) => const Center(child: Text('Image preview unavailable.')),
            ),
          ),
        ),
      ),
      const Text('Preview background only. Transparent pixels stay transparent in the saved PNG.'),
    ],
  );
}
class _Background extends CustomPainter {
  final String mode;
  _Background(this.mode);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = mode == 'dark' ? const Color(0xff202127) : Colors.white);
    if (mode != 'checkerboard') return;
    final paint = Paint()..color = const Color(0xffd6d6dc);
    for (var row = 0; row * 20 < size.height; row++) {
      for (var col = 0; col * 20 < size.width; col++) {
        if ((row + col).isEven) {
          canvas.drawRect(Rect.fromLTWH(col * 20.0, row * 20.0, 20, 20), paint);
        }
      }
    }
  }
  @override
  bool shouldRepaint(_Background oldDelegate) => oldDelegate.mode != mode;
}
